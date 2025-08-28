# frozen_string_literal: true

require_relative "emitter/base_emitter"
require_relative "emitter/emitters/json_emitter"
require_relative "emitter/emitters/yaml_emitter"
require_relative "emitter/emitters/llm_emitter"
require_relative "emitter/emitters/graphviz_emitter"
require_relative "emitter/emitter_manager"
require_relative "emitter/formatters/deterministic_formatter"
require_relative "emitter/processors/redactor"
require_relative "emitter/processors/cross_linker"

module Rubymap
  module Emitter
    class << self
      def emit(indexed_data, format: :json, output_dir: nil, **options)
        emitter = create_emitter(format, **options)

        if output_dir
          emitter.emit_to_directory(indexed_data, output_dir)
        else
          emitter.emit(indexed_data)
        end
      end

      def emit_all(indexed_data, output_dir, formats: [:json, :yaml, :llm, :graphviz], **options)
        manager = EmitterManager.new(**options)
        manager.emit_all(indexed_data, output_dir, formats: formats)
      end

      private

      def create_emitter(format, **options)
        case format
        when :json
          Emitters::JSON.new(**options)
        when :yaml
          Emitters::YAML.new(**options)
        when :llm
          Emitters::LLM.new(**options)
        when :graphviz, :dot
          Emitters::GraphViz.new(**options)
        else
          raise ArgumentError, "Unknown emitter format: #{format}"
        end
      end
    end
  end

  # Convenience aliases
  module Emitters
    JSON = Emitter::Emitters::JSON
    YAML = Emitter::Emitters::YAML
    LLM = Emitter::Emitters::LLM
    GraphViz = Emitter::Emitters::GraphViz
  end
end
