# frozen_string_literal: true

require_relative "class_converter"
require_relative "module_converter"
require_relative "method_converter"

module Rubymap
  class Enricher
    module Converters
      # Factory for creating appropriate converters for different entity types.
      #
      # This factory implements the Factory Method pattern, providing a central
      # point for converter creation and registration. It enables easy extension
      # for new entity types and maintains the open/closed principle.
      class ConverterFactory
        # Registry of entity types to converter classes
        CONVERTERS = {
          classes: ClassConverter,
          modules: ModuleConverter,
          methods: MethodConverter
        }.freeze

        class << self
          # Creates a converter for the specified entity type.
          #
          # @param entity_type [Symbol] The type of entity to convert (:classes, :modules, :methods)
          # @return [BaseConverter] Appropriate converter instance
          # @raise [ArgumentError] If entity type is not supported
          def create_converter(entity_type)
            converter_class = CONVERTERS[entity_type.to_sym]
            raise ArgumentError, "Unknown entity type: #{entity_type}" unless converter_class

            converter_class.new
          end

          # Gets all supported entity types.
          #
          # @return [Array<Symbol>] List of supported entity types
          def supported_types
            CONVERTERS.keys
          end

          # Registers a new converter for an entity type.
          #
          # This enables extension of the factory for custom entity types
          # without modifying the core factory code.
          #
          # @param entity_type [Symbol] The entity type identifier
          # @param converter_class [Class] The converter class
          def register_converter(entity_type, converter_class)
            unless converter_class < BaseConverter
              raise ArgumentError, "Converter must inherit from BaseConverter"
            end

            CONVERTERS[entity_type.to_sym] = converter_class
          end
        end
      end
    end
  end
end
