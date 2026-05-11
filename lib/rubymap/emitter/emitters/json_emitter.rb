# frozen_string_literal: true

require "json"

module Rubymap
  module Emitter
    module Emitters
      # Emits indexed data as JSON.
      #
      # Produces a deterministic, pretty-printed JSON representation of the
      # full indexed data including classes, modules, methods, metadata, and graphs.
      class JSON < BaseEmitter
        def emit(indexed_data)
          filtered = filter_data(indexed_data)
          formatted = apply_deterministic_formatting(filtered)
          ::JSON.pretty_generate(formatted)
        end

        protected

        def format_extension
          "json"
        end

        def default_filename
          "rubymap.json"
        end
      end
    end
  end
end
