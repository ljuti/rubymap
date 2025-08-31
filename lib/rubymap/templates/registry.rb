# frozen_string_literal: true

module Rubymap
  module Templates
    # Registry for managing template locations and overrides
    class Registry
      attr_reader :templates, :user_templates

      def initialize
        @templates = {}
        @user_templates = {}
        @loaded_defaults = false
      end

      # Register a template
      # @param format [Symbol] The output format (:llm, :markdown, :json, :yaml)
      # @param name [Symbol] The template name
      # @param path [String] The template file path
      def register(format, name, path)
        @templates[format] ||= {}
        @templates[format][name] = path
      end

      # Register a user template override
      def register_user_template(format, name, path)
        @user_templates[format] ||= {}
        @user_templates[format][name] = path
      end

      # Get a template path, preferring user templates over defaults
      # @param format [Symbol] The output format
      # @param name [Symbol] The template name
      # @return [String] The template path
      # @raise [TemplateNotFoundError] if template not found
      def get_template(format, name)
        # Load defaults if not already loaded
        load_defaults unless @loaded_defaults

        # Check user templates first
        if @user_templates.dig(format, name)
          return @user_templates[format][name]
        end

        # Fall back to default templates
        if @templates.dig(format, name)
          return @templates[format][name]
        end

        raise TemplateNotFoundError, "Template not found: #{format}/#{name}"
      end

      # Check if a template exists
      def template_exists?(format, name)
        load_defaults unless @loaded_defaults
        !!(@user_templates.dig(format, name) || @templates.dig(format, name))
      end

      # Load default templates from the gem's template directory
      def load_defaults
        return if @loaded_defaults

        default_dir = Templates.default_directory
        return unless File.directory?(default_dir)

        Dir.glob(File.join(default_dir, "**", "*.erb")).each do |path|
          relative_path = path.sub("#{default_dir}/", "")
          parts = relative_path.split("/")

          if parts.length >= 2
            format = parts[0].to_sym
            name = File.basename(parts[-1], ".erb").to_sym
            register(format, name, path)
          end
        end

        @loaded_defaults = true
      end

      # Load user templates from a directory
      # @param directory [String] The directory path containing user templates
      def load_user_templates(directory)
        return unless File.directory?(directory)

        Dir.glob(File.join(directory, "**", "*.erb")).each do |path|
          relative_path = path.sub("#{directory}/", "")
          parts = relative_path.split("/")

          if parts.length >= 2
            format = parts[0].to_sym
            name = File.basename(parts[-1], ".erb").to_sym
            register_user_template(format, name, path)
          elsif parts.length == 1
            # Allow flat structure for user templates
            name = File.basename(parts[0], ".erb")
            # Try to infer format from name (e.g., "llm_class.erb" -> format: llm, name: class)
            if name.include?("_")
              format_part, name_part = name.split("_", 2)
              register_user_template(format_part.to_sym, name_part.to_sym, path)
            end
          end
        end
      end

      # List all available templates
      def list_templates
        load_defaults unless @loaded_defaults

        all_templates = {}

        # Add default templates
        @templates.each do |format, templates|
          all_templates[format] ||= {}
          templates.each do |name, path|
            all_templates[format][name] = {path: path, type: :default}
          end
        end

        # Add/override with user templates
        @user_templates.each do |format, templates|
          all_templates[format] ||= {}
          templates.each do |name, path|
            all_templates[format][name] = {path: path, type: :user}
          end
        end

        all_templates
      end

      # Clear all registered templates (useful for testing)
      def clear!
        @templates.clear
        @user_templates.clear
        @loaded_defaults = false
      end
    end
  end
end
