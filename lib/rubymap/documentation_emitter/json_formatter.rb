# frozen_string_literal: true

require "json"

module Rubymap
  class DocumentationEmitter
    # Formats documentation data as JSON for machine-readable output.
    class JsonFormatter
      attr_reader :config

      def initialize(config = {})
        @config = config
      end

      # Formats the aggregated documentation data as JSON.
      #
      # @param data [Hash] The documentation data structure
      # @return [String] JSON-formatted documentation
      def format(data)
        filtered_data = filter_data(data)
        JSON.pretty_generate(filtered_data)
      end

      private

      def filter_data(data)
        filtered = {}

        filtered[:overview] = data[:overview] if data[:overview]
        filtered[:architecture] = data[:architecture] if data[:architecture]
        filtered[:api] = format_api_data(data[:api]) if data[:api]
        filtered[:classes] = format_classes_data(data[:classes]) if data[:classes]
        filtered[:modules] = format_modules_data(data[:modules]) if data[:modules]

        if @config[:include_relationships] && data[:relationships]
          filtered[:relationships] = data[:relationships]
        end

        if @config[:include_metrics] && data[:metrics]
          filtered[:metrics] = data[:metrics]
        end

        filtered[:issues] = data[:issues] if data[:issues]
        filtered[:patterns] = data[:patterns] if data[:patterns]
        filtered[:data_structures] = data[:data_structures] if data[:data_structures]

        filtered
      end

      def format_api_data(api)
        formatted = {}

        formatted[:public_methods] = format_methods(api[:public_methods]) if api[:public_methods]
        formatted[:protected_methods] = format_methods(api[:protected_methods]) if api[:protected_methods]

        if @config[:include_private] && api[:private_methods]
          formatted[:private_methods] = format_methods(api[:private_methods])
        end

        formatted
      end

      def format_methods(methods)
        return [] unless methods

        methods.map do |method|
          {
            name: method[:name],
            visibility: method[:visibility],
            scope: method[:scope],
            parameters: format_parameters(method[:parameters]),
            complexity: method[:complexity],
            lines: method[:lines],
            location: method[:location]
          }.compact
        end
      end

      def format_parameters(params)
        return [] unless params

        params.map do |param|
          {
            name: param[:name],
            type: param[:type],
            default: param[:default]
          }.compact
        end
      end

      def format_classes_data(classes)
        return [] unless classes

        classes.map do |klass|
          formatted = {
            name: klass[:name],
            fqname: klass[:fqname],
            namespace: klass[:namespace],
            superclass: klass[:superclass],
            location: klass[:location],
            mixins: klass[:mixins],
            methods: format_methods(klass[:methods]),
            constants: klass[:constants],
            attributes: klass[:attributes]
          }.compact

          if @config[:include_metrics]
            formatted[:metrics] = {
              complexity: klass[:complexity],
              cohesion: klass[:cohesion],
              coupling: klass[:coupling]
            }.compact
          end

          formatted
        end
      end

      def format_modules_data(modules)
        return [] unless modules

        modules.map do |mod|
          {
            name: mod[:name],
            fqname: mod[:fqname],
            namespace: mod[:namespace],
            location: mod[:location],
            methods: format_methods(mod[:methods]),
            constants: mod[:constants],
            included_in: mod[:included_in],
            extended_in: mod[:extended_in]
          }.compact
        end
      end
    end
  end
end
