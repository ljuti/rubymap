# frozen_string_literal: true

require_relative "templates/registry"
require_relative "templates/renderer"
require_relative "templates/context"
require_relative "templates/presenters"

module Rubymap
  # Template system for flexible output generation
  # Supports ERB templates with user overrides and customization
  module Templates
    class Error < StandardError; end

    class TemplateNotFoundError < Error; end

    class RenderError < Error; end

    class << self
      # Get the default templates directory
      def default_directory
        @default_directory ||= File.expand_path("../templates/default", __FILE__)
      end

      # Get or create the global template registry
      def registry
        @registry ||= Registry.new
      end

      # Convenience method to render a template
      def render(format, template_name, data, options = {})
        renderer = Renderer.new(format, options[:template_dir])
        renderer.render(template_name, data)
      end

      # Load user templates from a directory
      def load_user_templates(directory)
        registry.load_user_templates(directory)
      end

      # Initialize default templates
      def init!
        registry.load_defaults
      end
    end
  end
end
