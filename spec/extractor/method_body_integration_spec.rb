# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Method body recording integration" do
  include_context "sample Ruby code"

  let(:extractor) { Rubymap::Extractor.new }

  describe "extracting methods with calls" do
    it "populates calls_made on MethodInfo" do
      code = <<~RUBY
        class User
          def save
            Rails.logger.info("Saving user")
            validate!
            persist_to_db(@attributes)
          end
        end
      RUBY

      result = extractor.extract_from_code(code)
      method = result.methods.find { |m| m.name == "save" }

      expect(method).not_to be_nil
      expect(method.calls_made).to be_an(Array)
      expect(method.calls_made.size).to eq(3)

      # First call: Rails.logger.info("Saving user")
      call1 = method.calls_made.find { |c| c[:method] == "info" }
      expect(call1).not_to be_nil
      expect(call1[:receiver]).to eq(["Rails", "logger"])
      expect(call1[:arguments].size).to eq(1)
      expect(call1[:arguments][0]).to eq({type: :string, value: "Saving user"})

      # Second call: validate! (no receiver)
      call2 = method.calls_made.find { |c| c[:method] == "validate!" }
      expect(call2).not_to be_nil
      expect(call2[:receiver]).to be_nil
      expect(call2[:arguments]).to eq([])

      # Third call: persist_to_db(@attributes)
      call3 = method.calls_made.find { |c| c[:method] == "persist_to_db" }
      expect(call3).not_to be_nil
      expect(call3[:receiver]).to be_nil
      expect(call3[:arguments].size).to eq(1)
      expect(call3[:arguments][0][:type]).to eq(:instance_variable)
      expect(call3[:arguments][0][:value]).to eq("@attributes")
    end

    it "sets body_lines, loops, branches, conditionals from MethodBodyResult" do
      code = <<~RUBY
        class Worker
          def process_queue
            items.each do |item|
              process(item)
            end
            save_results
          end
        end
      RUBY

      result = extractor.extract_from_code(code)
      method = result.methods.find { |m| m.name == "process_queue" }

      expect(method).not_to be_nil
      expect(method.body_lines).to be > 0
      expect(method.loops).to be >= 1  # .each with block
      expect(method.branches).to eq(0)
      expect(method.conditionals).to eq(0)
    end

    it "serializes calls_made in to_h" do
      code = <<~RUBY
        class User
          def greet(name)
            puts "Hello, \#{name}"
          end
        end
      RUBY

      result = extractor.extract_from_code(code)
      method = result.methods.find { |m| m.name == "greet" }
      hash = method.to_h

      expect(hash).to have_key(:calls_made)
      expect(hash[:calls_made]).to be_an(Array)
      expect(hash[:calls_made].size).to eq(1)
      expect(hash[:calls_made].first[:method]).to eq("puts")
      expect(hash).to have_key(:branches)
      expect(hash).to have_key(:loops)
      expect(hash).to have_key(:conditionals)
      expect(hash).to have_key(:body_lines)
    end

    it "returns empty calls_made for methods with no calls" do
      code = <<~RUBY
        class Empty
          def nothing
            # just a comment
          end
        end
      RUBY

      result = extractor.extract_from_code(code)
      method = result.methods.find { |m| m.name == "nothing" }

      expect(method).not_to be_nil
      expect(method.calls_made).to eq([])
      expect(method.branches).to eq(0)
      expect(method.loops).to eq(0)
      expect(method.conditionals).to eq(0)
    end

    it "tracks multiple methods independently" do
      code = <<~RUBY
        class Service
          def method_a
            do_thing
          end

          def method_b
            other_thing
            more_stuff
          end
        end
      RUBY

      result = extractor.extract_from_code(code)

      method_a = result.methods.find { |m| m.name == "method_a" }
      method_b = result.methods.find { |m| m.name == "method_b" }

      expect(method_a.calls_made.size).to eq(1)
      expect(method_a.calls_made.first[:method]).to eq("do_thing")

      expect(method_b.calls_made.size).to eq(2)
      expect(method_b.calls_made.map { |c| c[:method] }).to contain_exactly("other_thing", "more_stuff")
    end

    it "records arguments with mixed types" do
      code = <<~RUBY
        class Mixed
          def configure
            setup(name: "app", timeout: 30, enabled: true, callback: nil, tags: [:ruby, :rails])
          end
        end
      RUBY

      result = extractor.extract_from_code(code)
      method = result.methods.find { |m| m.name == "configure" }
      args = method.calls_made.first[:arguments]

      # The keyword hash should be the first/last argument
      keyword_arg = args.find { |a| a[:type] == :hash }
      expect(keyword_arg).not_to be_nil
      expect(keyword_arg[:pairs].size).to eq(5)

      names = keyword_arg[:pairs].map { |p| p[:key] }
      expect(names).to contain_exactly("name", "timeout", "enabled", "callback", "tags")
    end
  end
end
