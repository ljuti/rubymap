# frozen_string_literal: true

require "yaml"

module Rubymap
  module Emitter
    module Emitters
      # Emits indexed data as YAML.
      #
      # Produces a human-readable YAML representation of the full indexed data
      # including classes, modules, methods, metadata, and graphs.
      class YAML < BaseEmitter
        def emit(indexed_data)
          filtered = filter_data(indexed_data)
          formatted = apply_deterministic_formatting(filtered)
          ::YAML.dump(formatted)
        end

        protected

        def format_extension
          "yaml"
        end

        def default_filename
          "rubymap.yaml"
        end
      end
    end
  end
end
