# frozen_string_literal: true

require_relative "lib/rubymap/version"

Gem::Specification.new do |spec|
  spec.name = "rubymap"
  spec.version = Rubymap.gem_version
  spec.authors = ["Lauri Jutila"]
  spec.email = ["git@laurijutila.com"]

  spec.summary = "A comprehensive Ruby codebase mapping tool"
  spec.description = "Rubymap creates a searchable, LLM-friendly knowledge graph of your Ruby application. " \
                      "It combines fast static analysis with optional runtime introspection to capture every aspect " \
                      "of your code - from class hierarchies to metaprogrammed methods, from Rails models to background jobs."
  spec.homepage = "https://github.com/ljuti/rubymap"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ljuti/rubymap"
  spec.metadata["changelog_uri"] = "https://github.com/ljuti/rubymap/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .standard.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Core dependencies for parsing and analysis
  spec.add_dependency "prism", "~> 1.0"  # Ruby parser
  spec.add_dependency "anyway_config", "~> 2.6"  # Configuration management

  # CLI dependencies
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "tty-progressbar", "~> 0.18"
  spec.add_dependency "tty-spinner", "~> 0.9"
  spec.add_dependency "tty-table", "~> 0.12"
  spec.add_dependency "pastel", "~> 0.8"
  spec.add_dependency "thor", "~> 1.3"

  # Development dependencies are in Gemfile

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
