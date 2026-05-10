# frozen_string_literal: true

require "spec_helper"
require "digest"

RSpec.describe "PipelineCache" do
  let(:cache_dir) { "tmp/pipeline_cache_test" }
  let(:cache) { Rubymap::PipelineCache.new(cache_dir) }
  let(:test_file) { "tmp/pipeline_cache_test_source.rb" }

  before do
    FileUtils.rm_rf(cache_dir)
    FileUtils.rm_rf(test_file)
  end

  after do
    FileUtils.rm_rf(cache_dir)
    FileUtils.rm_rf(test_file)
  end

  describe "#fetch" do
    it "returns nil for uncached file" do
      File.write(test_file, "class Foo; end")
      expect(cache.fetch(test_file)).to be_nil
    end

    it "returns stored data after store" do
      File.write(test_file, "class Foo; end")
      data = {classes: [{name: "Foo"}], file_path: test_file}
      cache.store(test_file, data)

      cached = cache.fetch(test_file)
      expect(cached).to eq(data)
    end

    it "returns nil when file has changed since caching" do
      File.write(test_file, "class Foo; end")
      cache.store(test_file, {classes: [{name: "Foo"}]})

      # Modify the file
      File.write(test_file, "class Bar; end")

      expect(cache.fetch(test_file)).to be_nil
    end

    it "returns data when file is unchanged" do
      File.write(test_file, "class Foo; end")
      cache.store(test_file, {classes: [{name: "Foo"}]})

      # Don't modify the file
      cached = cache.fetch(test_file)
      expect(cached).not_to be_nil
      expect(cached[:classes]).to eq([{name: "Foo"}])
    end

    it "survives Marshal round-trip for complex data" do
      File.write(test_file, "class Foo; end")
      data = {
        classes: [{name: "Foo", fqname: "Foo", type: "class", file: test_file, line: 1}],
        modules: [],
        methods: [{name: "bar", owner: "Foo", visibility: "public"}]
      }
      cache.store(test_file, data)

      cached = cache.fetch(test_file)
      expect(cached[:classes].first[:fqname]).to eq("Foo")
      expect(cached[:methods].first[:name]).to eq("bar")
    end
  end

  describe "#clear" do
    it "removes all cached entries" do
      File.write(test_file, "class Foo; end")
      cache.store(test_file, {classes: [{name: "Foo"}]})

      cache.clear

      expect(cache.fetch(test_file)).to be_nil
    end
  end

  describe "directory management" do
    it "creates cache directory if it does not exist" do
      FileUtils.rm_rf(cache_dir)
      cache = Rubymap::PipelineCache.new(cache_dir)
      File.write(test_file, "class Foo; end")
      cache.store(test_file, {})
      expect(Dir).to exist(cache_dir)
    end
  end
end
