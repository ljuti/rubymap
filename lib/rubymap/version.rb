# frozen_string_literal: true

module Rubymap
  def self.gem_version
    Gem::Version.new(Version::STRING)
  end

  module Version
    # Semantic versioning: MAJOR.MINOR.PATCH
    MAJOR = 0
    MINOR = 1
    PATCH = 0
    STRING = [MAJOR, MINOR, PATCH].join(".")
  end
end
