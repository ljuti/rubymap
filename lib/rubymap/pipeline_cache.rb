# frozen_string_literal: true

require "digest"
require "fileutils"

module Rubymap
  # Caches extracted file data keyed by file checksum.
  #
  # Avoids re-parsing unchanged files across pipeline runs. Each file's
  # extracted data is stored as a Marshaled hash, keyed by the SHA-256
  # of its absolute path. On fetch, the file's current checksum is compared
  # against the cached checksum — if they differ, the cache entry is
  # considered stale and nil is returned.
  #
  # @example
  #   cache = PipelineCache.new(".rubymap_cache")
  #   data = cache.fetch("app/models/user.rb")  # => nil or Hash
  #   cache.store("app/models/user.rb", classes: [...])
  #   cache.clear
  class PipelineCache
    def initialize(directory)
      @directory = directory
    end

    # Returns cached extracted data for a file, or nil if not cached or stale.
    #
    # @param file_path [String] Absolute or relative path to the source file
    # @return [Hash, nil] The cached extraction data, or nil
    def fetch(file_path)
      entry = read_entry(file_path)
      return nil unless entry
      return nil unless entry[:checksum] == checksum(file_path)

      entry[:data]
    end

    # Stores extracted data for a file.
    #
    # @param file_path [String] Path to the source file
    # @param data [Hash] The extraction data to cache
    def store(file_path, data)
      FileUtils.mkdir_p(@directory)

      entry = {
        checksum: checksum(file_path),
        data: data,
        stored_at: Time.now.iso8601
      }
      write_entry(file_path, entry)
    end

    # Removes all cached entries.
    def clear
      FileUtils.rm_rf(@directory)
    end

    private

    def checksum(path)
      Digest::SHA256.file(path).hexdigest
    end

    def entry_path(file_path)
      key = Digest::SHA256.hexdigest(File.expand_path(file_path))
      File.join(@directory, key)
    end

    def read_entry(file_path)
      path = entry_path(file_path)
      return nil unless File.exist?(path)

      Marshal.load(File.binread(path))
    rescue
      nil
    end

    def write_entry(file_path, entry)
      File.binwrite(entry_path(file_path), Marshal.dump(entry))
    end
  end
end
