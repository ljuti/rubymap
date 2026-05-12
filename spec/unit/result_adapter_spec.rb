# frozen_string_literal: true

require "spec_helper"

RSpec.describe "ResultAdapter" do
  let(:extractor) { Rubymap::Extractor.new }
  let(:test_dir) { "tmp/result_adapter_test" }

  before { FileUtils.mkdir_p(test_dir) }
  after { FileUtils.rm_rf(test_dir) }

  def extract(code)
    file = File.join(test_dir, "test.rb")
    File.write(file, code)
    extractor.extract_from_file(file)
  end

  describe ".adapt" do
    it "converts a Result to a hash with classes, modules, methods, constants" do
      result = extract(<<~RUBY)
        class User < ApplicationRecord
          def name; end
        end
      RUBY

      hash = Rubymap::ResultAdapter.adapt(result)

      expect(hash).to have_key(:classes)
      expect(hash).to have_key(:modules)
      expect(hash).to have_key(:methods)
      expect(hash).to have_key(:constants)
    end

    it "maps class fields correctly" do
      result = extract(<<~RUBY)
        class User < ApplicationRecord
          # A user model
          def name; end
        end
      RUBY

      hash = Rubymap::ResultAdapter.adapt(result)
      klass = hash[:classes].first

      expect(klass[:name]).to eq("User")
      expect(klass[:type]).to eq("class")
      expect(klass[:superclass]).to eq("ApplicationRecord")
      expect(klass[:line]).to be > 0
      expect(klass[:file]).to include("test.rb")
    end

    it "maps module fields correctly" do
      result = extract(<<~RUBY)
        module Helpers
          def assist; end
        end
      RUBY

      hash = Rubymap::ResultAdapter.adapt(result)
      mod = hash[:modules].first

      expect(mod[:name]).to eq("Helpers")
      expect(mod[:type]).to eq("module")
      expect(mod[:file]).to include("test.rb")
    end

    it "maps method fields correctly" do
      result = extract(<<~RUBY)
        class User
          def full_name(first, last)
            "first + " " + last"
          end
        end
      RUBY

      hash = Rubymap::ResultAdapter.adapt(result)
      method = hash[:methods].first

      expect(method[:name]).to eq("full_name")
      expect(method[:owner]).to eq("User")
      expect(method[:visibility]).to be_a(String)
    end

    it "maps constant fields correctly" do
      result = extract(<<~RUBY)
        class Config
          MAX_SIZE = 100
        end
      RUBY

      hash = Rubymap::ResultAdapter.adapt(result)
      const = hash[:constants].first

      expect(const[:name]).to eq("MAX_SIZE")
      expect(const[:line]).to be > 0
    end

    it "returns empty arrays for empty Result" do
      result = extract("# just a comment")
      hash = Rubymap::ResultAdapter.adapt(result)

      expect(hash[:classes]).to eq([])
      expect(hash[:modules]).to eq([])
      expect(hash[:methods]).to eq([])
      expect(hash[:constants]).to eq([])
    end

    it "handles class with no superclass" do
      result = extract(<<~RUBY)
        class PlainClass
        end
      RUBY

      hash = Rubymap::ResultAdapter.adapt(result)
      expect(hash[:classes].first[:superclass]).to be_nil
    end

    it "returns all data types including mixins, attributes, dependencies, patterns, class_variables, aliases, method_calls" do
      result = extract(<<~RUBY)
        module Searchable
          included do
            has_many :searches
          end
        end

        class User < ApplicationRecord
          include Searchable
          attr_accessor :name, :email
          @@count = 0
          MAX_SIZE = 100
          alias :full_name :name

          def authenticate(password)
            logger.info("auth")
            valid_password?(password)
          end
        end
      RUBY

      hash = Rubymap::ResultAdapter.adapt(result)

      expect(hash).to have_key(:mixins)
      expect(hash).to have_key(:attributes)
      expect(hash).to have_key(:dependencies)
      expect(hash).to have_key(:patterns)
      expect(hash).to have_key(:class_variables)
      expect(hash).to have_key(:aliases)
      expect(hash).to have_key(:method_calls)
    end

    it "method hash includes Phase 1 intra-method fields" do
      result = extract(<<~RUBY)
        class User
          def process(items)
            items.each do |item|
              if item.valid?
                save(item)
              else
                log_error(item)
              end
            end
          end
        end
      RUBY

      hash = Rubymap::ResultAdapter.adapt(result)
      method = hash[:methods].find { |m| m[:name] == "process" }

      expect(method).to have_key(:calls_made)
      expect(method).to have_key(:branches)
      expect(method).to have_key(:loops)
      expect(method).to have_key(:conditionals)
      expect(method).to have_key(:body_lines)
    end
  end
end
