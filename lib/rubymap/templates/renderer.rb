# frozen_string_literal: true

require "erb"

module Rubymap
  module Templates
    # Renders templates using ERB
    class Renderer
      attr_reader :format, :template_dir, :registry

      def initialize(format, template_dir = nil)
        @format = format
        @template_dir = template_dir
        @registry = Templates.registry
        @template_cache = {}

        # Load user templates if directory provided
        @registry.load_user_templates(template_dir) if template_dir
      end

      # Render a template with the given data
      # @param template_name [Symbol, String] The template name
      # @param data [Hash, Context] The data to render
      # @return [String] The rendered output
      def render(template_name, data)
        template_name = template_name.to_sym
        context = prepare_context(data)

        template = load_template(template_name)
        template.result(context.get_binding)
      rescue => e
        raise RenderError, "Failed to render template #{format}/#{template_name}: #{e.message}"
      end

      # Render a collection using a template
      # @param template_name [Symbol, String] The template name
      # @param collection [Array] The collection to render
      # @param separator [String] The separator between items
      # @return [String] The rendered output
      def render_collection(template_name, collection, separator = "\n")
        return "" if collection.nil? || collection.empty?

        collection.map do |item|
          render(template_name, item)
        end.join(separator)
      end

      # Render a partial template
      # @param partial_name [Symbol, String] The partial template name (without leading underscore)
      # @param locals [Hash] Local variables for the partial
      # @return [String] The rendered partial
      def render_partial(partial_name, locals = {})
        partial_name = "_#{partial_name}" unless partial_name.to_s.start_with?("_")
        render(partial_name, locals)
      end

      private

      def prepare_context(data)
        case data
        when Context
          data.renderer = self
          data
        when Hash
          Context.new(data, renderer: self)
        else
          # Assume it's a data object that can be wrapped
          Context.new({data: data}, renderer: self)
        end
      end

      def load_template(template_name)
        cache_key = "#{format}/#{template_name}"

        # Return cached template if available (in production mode)
        return @template_cache[cache_key] if @template_cache[cache_key] && !development_mode?

        # Get template path from registry
        template_path = @registry.get_template(format, template_name)

        # Read and compile template
        template_content = File.read(template_path)
        template = ERB.new(template_content, trim_mode: "-")

        # Cache the compiled template
        @template_cache[cache_key] = template

        template
      end

      def development_mode?
        ENV["RUBYMAP_ENV"] == "development" || ENV["RUBYMAP_NO_CACHE"] == "true"
      end
    end
  end
end
