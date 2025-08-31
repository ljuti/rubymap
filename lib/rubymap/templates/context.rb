# frozen_string_literal: true

module Rubymap
  module Templates
    # Execution context for templates, providing data access and helper methods
    class Context
      attr_accessor :renderer
      attr_reader :data

      def initialize(data = {}, options = {})
        @data = data
        @renderer = options[:renderer]
        @helpers = options[:helpers] || {}

        # Make data available as instance variables
        data.each do |key, value|
          instance_variable_set("@#{key}", value)
        end
      end

      # Get the binding for ERB evaluation
      def get_binding
        binding
      end

      # Render a partial template
      def render_partial(partial_name, locals = {})
        return "" unless @renderer

        # Merge current context data with locals
        partial_data = @data.merge(locals)
        @renderer.render_partial(partial_name, partial_data)
      end

      # Render a collection with a template
      def render_collection(template_name, collection, separator = "\n")
        return "" unless @renderer && collection

        @renderer.render_collection(template_name, collection, separator)
      end

      # Include another template
      def include_template(template_name, locals = {})
        return "" unless @renderer

        template_data = @data.merge(locals)
        @renderer.render(template_name, template_data)
      end

      # === Template Helper Methods ===

      # Format a method signature
      def format_method_signature(method)
        return "" unless method

        prefix = (method[:scope] == "class") ? "." : "#"
        params = format_parameters(method[:parameters] || method[:params])

        "#{prefix}#{method[:name]}#{params}"
      end

      # Format method parameters
      def format_parameters(params)
        return "()" if params.nil? || params.empty?

        formatted = params.map do |param|
          format_parameter(param)
        end.join(", ")

        "(#{formatted})"
      end

      # Format a single parameter
      def format_parameter(param)
        return param.to_s unless param.is_a?(Hash)

        case param[:type]
        when "required"
          param[:name]
        when "optional"
          "#{param[:name]} = #{param[:default]}"
        when "rest"
          "*#{param[:name]}"
        when "keyword"
          "#{param[:name]}:"
        when "keyword_optional"
          "#{param[:name]}: #{param[:default]}"
        when "keyword_rest"
          "**#{param[:name]}"
        when "block"
          "&#{param[:name]}"
        else
          param[:name] || param.to_s
        end
      end

      # Format location information
      def format_location(location)
        return "" unless location

        if location.is_a?(Hash)
          if location[:file] && location[:line]
            "#{location[:file]}:#{location[:line]}"
          elsif location["file"] && location["line"]
            "#{location["file"]}:#{location["line"]}"
          else
            ""
          end
        else
          location.to_s
        end
      end

      # Generate a complexity label
      def complexity_label(score)
        return "low" unless score

        if score > 7
          "high"
        elsif score > 4
          "medium"
        else
          "low"
        end
      end

      # Escape markdown special characters
      def escape_markdown(text)
        return "" unless text

        text.to_s
          .gsub("*", "\\*")
          .gsub("_", "\\_")
          .gsub("`", "\\`")
          .gsub("#", "\\#")
          .gsub("|", "\\|")
      end

      # Generate purpose text for a class
      def generate_purpose_text(klass)
        return "" unless klass

        name = klass[:fqname] || klass[:name] || "Unknown"
        last_component = name.to_s.split("::").last

        "This class encapsulates the behavior and data for #{last_component} entities in the system. " \
        "It is responsible for maintaining the state and providing the interface for #{name} operations."
      end

      # Generate overview text for a class
      def generate_overview_text(klass)
        return "" unless klass

        name = klass[:fqname] || klass[:name] || "Unknown"
        last_component = name.to_s.split("::").last

        "The #{name} class provides core functionality within the application. " \
        "It defines the structure and behavior for #{last_component} entities."
      end

      # Check if a value is present (not nil or empty)
      def present?(value)
        !blank?(value)
      end

      # Check if a value is blank (nil or empty)
      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      # Pluralize a word (simple version)
      def pluralize(count, singular, plural = nil)
        plural ||= "#{singular}s"
        (count == 1) ? "#{count} #{singular}" : "#{count} #{plural}"
      end

      # Join an array with commas and "and"
      def to_sentence(array, options = {})
        return "" if array.nil? || array.empty?
        return array[0].to_s if array.size == 1

        last_word = options[:last_word] || "and"

        if array.size == 2
          "#{array[0]} #{last_word} #{array[1]}"
        else
          "#{array[0..-2].join(", ")}, #{last_word} #{array[-1]}"
        end
      end

      # Truncate text to a maximum length
      def truncate(text, length = 100, omission = "...")
        return "" unless text

        text = text.to_s
        return text if text.length <= length

        text[0...(length - omission.length)] + omission
      end

      # Access to custom helpers
      def method_missing(method_name, *args, &block)
        if @helpers.key?(method_name)
          @helpers[method_name].call(*args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @helpers.key?(method_name) || super
      end
    end
  end
end
