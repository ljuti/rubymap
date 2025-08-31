# frozen_string_literal: true

require "yaml"

module Rubymap
  class DocumentationEmitter
    # Formats documentation data as YAML for configuration-friendly output.
    class YamlFormatter
      attr_reader :config

      def initialize(config = {})
        @config = config
      end

      # Formats the aggregated documentation data as YAML.
      #
      # @param data [Hash] The documentation data structure
      # @return [String] YAML-formatted documentation
      def format(data)
        filtered_data = filter_data(data)
        YAML.dump(filtered_data)
      end

      private

      def filter_data(data)
        filtered = {}

        filtered["overview"] = clean_for_yaml(data[:overview]) if data[:overview]
        filtered["architecture"] = clean_for_yaml(data[:architecture]) if data[:architecture]
        filtered["api"] = format_api_data(data[:api]) if data[:api]
        filtered["classes"] = format_classes_data(data[:classes]) if data[:classes]
        filtered["modules"] = format_modules_data(data[:modules]) if data[:modules]

        if @config[:include_relationships] && data[:relationships]
          filtered["relationships"] = clean_for_yaml(data[:relationships])
        end

        if @config[:include_metrics] && data[:metrics]
          filtered["metrics"] = clean_for_yaml(data[:metrics])
        end

        filtered["issues"] = clean_for_yaml(data[:issues]) if data[:issues]
        filtered["patterns"] = clean_for_yaml(data[:patterns]) if data[:patterns]
        filtered["data_structures"] = clean_for_yaml(data[:data_structures]) if data[:data_structures]

        filtered
      end

      def format_api_data(api)
        formatted = {}

        formatted["public_methods"] = format_methods(api[:public_methods]) if api[:public_methods]
        formatted["protected_methods"] = format_methods(api[:protected_methods]) if api[:protected_methods]

        if @config[:include_private] && api[:private_methods]
          formatted["private_methods"] = format_methods(api[:private_methods])
        end

        formatted
      end

      def format_methods(methods)
        return [] unless methods

        methods.map do |method|
          clean_for_yaml({
            "name" => method[:name],
            "visibility" => method[:visibility],
            "scope" => method[:scope],
            "parameters" => format_parameters(method[:parameters]),
            "complexity" => method[:complexity],
            "lines" => method[:lines],
            "location" => format_location(method[:location])
          })
        end
      end

      def format_parameters(params)
        return [] unless params

        params.map do |param|
          clean_for_yaml({
            "name" => param[:name],
            "type" => param[:type],
            "default" => param[:default]
          })
        end
      end

      def format_classes_data(classes)
        return [] unless classes

        classes.map do |klass|
          formatted = {
            "name" => klass[:name],
            "fqname" => klass[:fqname],
            "namespace" => klass[:namespace],
            "superclass" => klass[:superclass],
            "location" => format_location(klass[:location]),
            "mixins" => klass[:mixins],
            "methods" => format_methods(klass[:methods]),
            "constants" => klass[:constants],
            "attributes" => klass[:attributes]
          }

          if @config[:include_metrics]
            formatted["metrics"] = clean_for_yaml({
              "complexity" => klass[:complexity],
              "cohesion" => klass[:cohesion],
              "coupling" => klass[:coupling]
            })
          end

          clean_for_yaml(formatted)
        end
      end

      def format_modules_data(modules)
        return [] unless modules

        modules.map do |mod|
          clean_for_yaml({
            "name" => mod[:name],
            "fqname" => mod[:fqname],
            "namespace" => mod[:namespace],
            "location" => format_location(mod[:location]),
            "methods" => format_methods(mod[:methods]),
            "constants" => mod[:constants],
            "included_in" => mod[:included_in],
            "extended_in" => mod[:extended_in]
          })
        end
      end

      def format_location(location)
        return nil unless location

        clean_for_yaml({
          "file" => location[:file],
          "line" => location[:line],
          "column" => location[:column]
        })
      end

      # Clean hash for YAML output by removing nil values and converting symbols to strings
      def clean_for_yaml(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(k, v), result|
            cleaned_value = clean_for_yaml(v)
            result[k.to_s] = cleaned_value unless cleaned_value.nil?
          end
        when Array
          obj.map { |item| clean_for_yaml(item) }.compact
        when Symbol
          obj.to_s
        else
          obj
        end
      end
    end
  end
end
