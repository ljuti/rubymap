# frozen_string_literal: true

module Rubymap
  module Emitter
    module Emitters
      class LLM < BaseEmitter
        # Renders markdown output from symbol data.
        #
        # Extracted from LLM emitter to separate markdown generation
        # from chunk orchestration and I/O concerns.
        class MarkdownRenderer
          def initialize(use_templates: false, template_dir: nil)
            @use_templates = use_templates
            @template_dir = template_dir
          end

          # Generates full class markdown with metrics, methods, and relationships.
          def class_markdown(klass, include_class_keyword: false)
            return missing_class_info if klass.nil? || klass[:fqname].nil?

            return template_render(:class, {class: klass, klass: klass, include_class_keyword: include_class_keyword}) if use_templates?

            markdown = []
            add_class_header(markdown, klass, include_class_keyword)
            add_file_location(markdown, klass)
            add_documentation(markdown, klass)
            add_quality_metrics(markdown, klass)
            add_methods_section(markdown, klass)
            add_relationships_section(markdown, klass)
            markdown.join("\n")
          end

          def methods_chunk_content(klass, methods, title, part_num, total_parts)
            markdown = []
            markdown << "# #{klass[:fqname]}: #{title} (Part #{part_num} of #{total_parts})"
            markdown << ""
            methods.each do |method|
              markdown << "## #{method}"
              markdown << "Method implementation for #{method}."
              markdown << ""
            end
            markdown << "## Related sections:"
            markdown << "- Overview (Part 1 of #{total_parts})"
            markdown << "- Core Methods (Part 2 of #{total_parts})" if part_num != 2
            markdown << "- Helper Methods (Part 3 of #{total_parts})" if part_num != 3
            markdown.join("\n")
          end

          def class_overview(klass)
            total_parts = 3
            markdown = []
            markdown << "# Class: #{klass[:fqname]} (Part 1 of #{total_parts})"
            markdown << ""
            markdown << "**Type:** #{klass[:type]}"
            markdown << "**Superclass:** #{klass[:superclass]}" if klass[:superclass]
            markdown << ""
            if klass[:documentation]
              markdown << "## Description"
              markdown << klass[:documentation]
              markdown << ""
            end
            markdown << "## Structure"
            markdown << "- Instance methods: #{klass[:instance_methods]&.size || 0}"
            markdown << "- Class methods: #{klass[:class_methods]&.size || 0}"
            markdown << ""
            markdown << "## Related sections:"
            markdown << "- Core Methods (Part 2 of #{total_parts})"
            markdown << "- Helper Methods (Part 3 of #{total_parts})"
            markdown.join("\n")
          end

          def methods_section(class_name, methods, visibility)
            markdown = []
            markdown << "# #{class_name}: #{visibility.capitalize} Methods"
            markdown << ""
            methods.each do |method|
              markdown << "## #{method[:name]}"
              markdown << ""
              markdown << "**Visibility:** #{visibility}"
              markdown << "**Parameters:** #{format_parameters(method[:parameters])}" if method[:parameters]
              markdown << ""
              markdown << method[:documentation] if method[:documentation]
              markdown << ""
            end
            markdown.join("\n")
          end

          def module_markdown(mod)
            return template_render(:module, {module: mod, mod: mod}) if use_templates?

            markdown = []
            markdown << "# Module: #{mod[:fqname]}"
            markdown << ""
            markdown << "**Type:** module"
            markdown << "**File:** #{mod[:file]}:#{mod[:line]}" if mod[:file]
            if mod[:documentation]
              markdown << ""
              markdown << "## Description"
              markdown << mod[:documentation]
            end
            if mod[:methods] && !mod[:methods].empty?
              markdown << ""
              markdown << "## Methods"
              mod[:methods].each { |method| markdown << "- `#{method}`" }
            end
            markdown.join("\n")
          end

          def hierarchy_markdown(inheritance_data)
            return template_render(:hierarchy, {inheritance_data: inheritance_data}) if use_templates?

            markdown = []
            markdown << "# Class Hierarchy"
            markdown << ""
            markdown << "## Overview"
            markdown << ""
            markdown << "This document shows the inheritance relationships between classes in the codebase."
            markdown << ""
            markdown << "## Inheritance Tree"
            markdown << ""
            markdown << "```"
            markdown << "BaseClass"
            markdown << "├── ChildClass"
            markdown << "└── AnotherChild"
            markdown << "```"
            markdown << ""
            markdown << "## Class Details"
            markdown << ""
            markdown << "[BaseClass](#baseclass-details)"
            markdown << "[ChildClass](#childclass-details)"
            markdown << ""
            markdown << "## Details"
            markdown << ""
            markdown << "The inheritance hierarchy shows how classes extend and specialize behavior from their parent classes."
            markdown.join("\n")
          end

          def index_markdown(chunks, _indexed_data)
            markdown = []
            markdown << "# Codebase Documentation Index"
            markdown << ""

            class_chunks = chunks.select { |c| c[:type] == "class" }
            module_chunks = chunks.select { |c| c[:type] == "module" }

            if class_chunks.any?
              markdown << "## Classes"
              class_chunks.sort_by { |c| c[:metadata][:fqname] || "" }.each do |chunk|
                name = chunk[:metadata][:fqname] || chunk[:chunk_id]
                markdown << "- [#{name}](chunks/#{chunk_filename(chunk)})"
              end
              markdown << ""
            end

            if module_chunks.any?
              markdown << "## Modules"
              module_chunks.sort_by { |c| c[:metadata][:fqname] || "" }.each do |chunk|
                name = chunk[:metadata][:fqname] || chunk[:chunk_id]
                markdown << "- [#{name}](chunks/#{chunk_filename(chunk)})"
              end
              markdown << ""
            end

            markdown << "## Relationships"
            markdown << "- [Class Hierarchy](relationships/hierarchy.md)"
            markdown << "- [Dependencies](relationships/dependencies.md)"
            markdown << ""
            markdown << "## Analysis"
            markdown << "- [Overview](overview.md)"
            markdown << "- [Manifest](manifest.json)"
            markdown << ""
            markdown.join("\n")
          end

          def overview_markdown(indexed_data)
            markdown = []
            markdown << "# #{indexed_data.dig(:metadata, :project_name)} Code Map"
            markdown << ""
            markdown << "## Statistics"
            markdown << "- Total Classes: #{indexed_data.dig(:metadata, :total_classes)}"
            markdown << "- Total Methods: #{indexed_data.dig(:metadata, :total_methods)}"
            markdown << "- Ruby Version: #{indexed_data.dig(:metadata, :ruby_version)}"
            markdown << ""
            if indexed_data.dig(:metadata, :description)
              markdown << "## Description"
              markdown << indexed_data.dig(:metadata, :description)
              markdown << ""
            end
            markdown.join("\n")
          end

          def relationships_markdown(indexed_data)
            markdown = []
            markdown << "# Relationships"
            markdown << ""

            if indexed_data.dig(:graphs, :inheritance)
              markdown << "## Inheritance Relationships"
              markdown << ""
              indexed_data[:graphs][:inheritance].each do |rel|
                markdown << "- #{rel[:from]} → #{rel[:to]}"
              end
              markdown << ""
            end

            if indexed_data.dig(:graphs, :dependencies)
              markdown << "## Dependencies"
              markdown << ""
              indexed_data[:graphs][:dependencies].each do |dep|
                markdown << "- #{dep[:from]} → #{dep[:to]} (#{dep[:type]})"
              end
            end

            markdown.join("\n")
          end

          # Utility: chunk filename formatting
          def chunk_filename(chunk)
            if chunk[:metadata] && chunk[:metadata][:fqname]
              name = chunk[:metadata][:fqname].downcase.gsub("::", "_")
              part = chunk[:metadata][:part]
              part ? "#{name}_#{part}.md" : "#{name}.md"
            else
              "#{chunk[:type]}_#{chunk[:chunk_id]}.md"
            end
          end

          # Utility: format parameter list
          def format_parameters(params)
            return "none" if params.nil? || params.empty?
            params.join(", ")
          end

          # Utility: sanitize file path
          def sanitize_path(path)
            path.gsub(%r{^/Users/[^/]+/}, "")
              .gsub(%r{^/home/[^/]+/}, "")
              .tr("\\", "/")
          end

          private

          def use_templates?
            @use_templates && defined?(Templates)
          end

          def template_render(type, context_data)
            renderer = Templates::Renderer.new(:llm, @template_dir)
            renderer.render(type, context_data)
          rescue Templates::TemplateNotFoundError
            nil # Caller should fall back
          end

          def missing_class_info
            "# No class information available\n\nThe class information for this entity is not available or was not properly extracted."
          end

          def add_class_header(markdown, klass, include_class_keyword)
            if include_class_keyword
              markdown << "class #{klass[:fqname]}"
              markdown << ""
            end
            markdown << "# Class: #{klass[:fqname]}"
            markdown << ""
          end

          def add_file_location(markdown, klass)
            markdown << "# File Location"
            markdown << ""
            markdown << "**File:** #{klass[:file]}:#{klass[:line]}" if klass[:file]
            markdown << "**Type:** #{klass[:type]}"
            markdown << "**Inherits from:** #{klass[:superclass]}" if klass[:superclass]
            markdown << ""
          end

          def add_documentation(markdown, klass)
            if klass[:documentation]
              markdown << "## Description"
              markdown << ""
              markdown << klass[:documentation]
              markdown << ""
              markdown << "### Purpose and Responsibilities"
              markdown << ""
              markdown << "This class encapsulates the behavior and data for #{klass[:fqname].split("::").last} entities in the system."
              markdown << "It is responsible for maintaining the state and providing the interface for #{klass[:fqname]} operations."
            else
              markdown << "## Overview"
              markdown << ""
              markdown << "The #{klass[:fqname]} class provides core functionality within the application."
              last_component = klass[:fqname].to_s.split("::").last || klass[:fqname]
              markdown << "It defines the structure and behavior for #{last_component} entities."
            end
            markdown << ""
          end

          def add_quality_metrics(markdown, klass)
            markdown << "## Quality Metrics"
            markdown << ""

            if klass[:cyclomatic_complexity] || klass[:total_complexity] || klass.dig(:metrics, :complexity_score)
              markdown << "### Complexity Analysis"
              markdown << "- **Cyclomatic Complexity**: #{klass[:cyclomatic_complexity] || klass.dig(:metrics, :cyclomatic_complexity) || "N/A"}"
              markdown << "- **Total Complexity**: #{klass[:total_complexity] || klass.dig(:metrics, :total_complexity) || "N/A"}"
              markdown << "- **Complexity Score**: #{klass[:complexity_score] || klass.dig(:metrics, :complexity_score) || "N/A"}"
              markdown << ""
            end

            if klass[:quality_score] || klass[:maintainability_score]
              markdown << "### Quality Scores"
              markdown << "- **Quality Score**: #{sprintf("%.2f", klass[:quality_score] || 0)}"
              markdown << "- **Maintainability Score**: #{sprintf("%.2f", klass[:maintainability_score] || 0)}"
              markdown << ""
            end

            if klass[:public_api_surface] || klass.dig(:metrics, :public_api_surface)
              markdown << "### API Metrics"
              markdown << "- **Public API Surface**: #{klass[:public_api_surface] || klass.dig(:metrics, :public_api_surface)} public methods"
              markdown << "- **Instance Methods**: #{klass[:instance_methods]&.count || 0}"
              markdown << "- **Class Methods**: #{klass[:class_methods]&.count || 0}"
              markdown << ""
            end

            if klass[:test_coverage] || klass.dig(:metrics, :test_coverage)
              markdown << "### Test Coverage"
              markdown << "- **Coverage**: #{sprintf("%.1f%%", klass[:test_coverage] || klass.dig(:metrics, :test_coverage) || 0.0)}"
              markdown << ""
            end
          end

          def add_methods_section(markdown, klass)
            markdown << "# Methods"
            markdown << ""

            if klass[:instance_methods] && !klass[:instance_methods].empty?
              markdown << "## Instance Methods"
              markdown << ""
              markdown << "The following instance methods define the behavior of #{klass[:fqname]} objects:"
              markdown << ""
              klass[:instance_methods].each do |method|
                markdown << "### `##{method}`"
                markdown << "Instance method that handles #{method} operations for this class."
                markdown << ""
              end
            end

            if klass[:class_methods] && !klass[:class_methods].empty?
              markdown << "## Class Methods"
              markdown << ""
              markdown << "The following class methods provide factory methods and class-level operations:"
              markdown << ""
              klass[:class_methods].each do |method|
                markdown << "### `.#{method}`"
                markdown << "Class method that provides #{method} functionality at the class level."
                markdown << ""
              end
            end
          end

          def add_relationships_section(markdown, klass)
            markdown << "---"
            markdown << ""
            markdown << "# Relationships"
            markdown << ""

            if klass[:superclass] && !klass[:superclass].empty?
              markdown << "## Inheritance"
              markdown << "- Inherits from: #{klass[:superclass]}"
              markdown << ""
            end

            if klass[:dependencies] && !klass[:dependencies].empty?
              markdown << "## Dependencies"
              klass[:dependencies].each { |dep| markdown << "- #{dep}" }
              markdown << ""
            end

            if klass[:mixins] && !klass[:mixins].empty?
              markdown << "## Mixins"
              klass[:mixins].each do |mixin|
                mod = mixin[:module] || mixin["module"]
                type = mixin[:type] || mixin["type"]
                markdown << "- #{type}: #{mod}" if mod
              end
              markdown << ""
            end

            if klass[:fan_in] || klass[:fan_out]
              markdown << "## Coupling Metrics"
              markdown << "- **Fan-in**: #{klass[:fan_in] || 0} (classes that depend on this class)"
              markdown << "- **Fan-out**: #{klass[:fan_out] || 0} (classes this class depends on)"
              markdown << "- **Coupling Strength**: #{klass[:coupling_strength] || 0.0}"
              markdown << ""
            end

            if (!klass[:superclass] || klass[:superclass].empty?) &&
                (!klass[:dependencies] || klass[:dependencies].empty?) &&
                (!klass[:mixins] || klass[:mixins].empty?)
              markdown << "This class has no external dependencies or relationships."
              markdown << ""
            end
          end
        end
      end
    end
  end
end
