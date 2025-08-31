# frozen_string_literal: true

module Rubymap
  class DocumentationEmitter
    # Formats documentation data as Markdown for human-readable output.
    class MarkdownFormatter
      attr_reader :config

      def initialize(config = {})
        @config = config
      end

      # Formats the aggregated documentation data as Markdown.
      #
      # @param data [Hash] The documentation data structure
      # @return [String] Markdown-formatted documentation
      def format(data)
        markdown = []

        if data[:overview]
          markdown << format_overview(data[:overview])
          markdown << ""
        end

        if data[:architecture]
          markdown << format_architecture(data[:architecture])
          markdown << ""
        end

        if data[:api]
          markdown << format_api(data[:api])
          markdown << ""
        end

        if data[:classes]
          markdown << format_classes(data[:classes])
          markdown << ""
        end

        if data[:modules]
          markdown << format_modules(data[:modules])
          markdown << ""
        end

        if data[:relationships] && @config[:include_relationships]
          markdown << format_relationships(data[:relationships])
          markdown << ""
        end

        if data[:metrics] && @config[:include_metrics]
          markdown << format_metrics(data[:metrics])
          markdown << ""
        end

        if data[:issues]
          markdown << format_issues(data[:issues])
          markdown << ""
        end

        if data[:patterns]
          markdown << format_patterns(data[:patterns])
          markdown << ""
        end

        markdown.join("\n").strip
      end

      private

      def format_overview(overview)
        lines = ["# Component Overview\n"]

        if overview[:name]
          lines << "## #{overview[:name]}"
          lines << "**Type**: #{overview[:type]}" if overview[:type]
          lines << "**Namespace**: `#{overview[:namespace]}`" if overview[:namespace] && !overview[:namespace].empty?
          lines << "**Location**: `#{overview[:location][:file]}:#{overview[:location][:line]}`" if overview[:location]

          # Add @rubymap summary if present
          if overview[:rubymap]
            lines << ""
            lines << "**Summary**: #{overview[:rubymap]}"
          end

          # Add documentation if present
          if overview[:documentation]
            lines << ""
            lines << "### Description"
            lines << ""
            lines << overview[:documentation]
          end

          lines << ""
        else
          # Full codebase overview
          lines << "## Codebase Statistics"
          lines << "- **Classes**: #{overview[:total_classes]}" if overview[:total_classes]
          lines << "- **Modules**: #{overview[:total_modules]}" if overview[:total_modules]
          lines << "- **Methods**: #{overview[:total_methods]}" if overview[:total_methods]
          lines << "- **Files**: #{overview[:total_files]}" if overview[:total_files]
          lines << "- **Lines of Code**: #{overview[:total_loc]}" if overview[:total_loc]
          lines << "- **Average Complexity**: #{overview[:avg_complexity]}" if overview[:avg_complexity]
          lines << "- **Test Coverage**: #{overview[:coverage]}%" if overview[:coverage]
        end

        lines.join("\n")
      end

      def format_architecture(architecture)
        lines = ["## Architecture\n"]

        lines << "```"
        lines << "#{architecture[:namespace_path].join("::")} (#{architecture[:file_path]})"

        if architecture[:inheritance]
          lines << "  ├── inherits: #{architecture[:inheritance]}"
        end

        if architecture[:mixins] && !architecture[:mixins].empty?
          architecture[:mixins].each_with_index do |mixin, i|
            prefix = (i == architecture[:mixins].size - 1) ? "└──" : "├──"
            lines << "  #{prefix} #{mixin[:type]}: #{mixin[:module]}"
          end
        end

        lines << "```"
        lines.join("\n")
      end

      def format_api(api)
        lines = ["## Public API\n"]

        if api[:public_methods] && !api[:public_methods].empty?
          lines << "### Public Methods"
          lines << ""
          api[:public_methods].each do |method|
            lines << format_method(method)
          end
        end

        if api[:protected_methods] && !api[:protected_methods].empty?
          lines << "### Protected Methods"
          lines << ""
          api[:protected_methods].each do |method|
            lines << format_method(method)
          end
        end

        if api[:private_methods] && !api[:private_methods].empty?
          lines << "### Private Methods"
          lines << ""
          api[:private_methods].each do |method|
            lines << format_method(method)
          end
        end

        lines.join("\n")
      end

      def format_method(method)
        lines = []

        # Method signature
        signature = "#### `#{(method[:scope] == "class") ? "." : "#"}#{method[:name]}"
        if method[:parameters] && !method[:parameters].empty?
          params = method[:parameters].map { |p| format_parameter(p) }.join(", ")
          signature += "(#{params})"
        else
          signature += "()"
        end
        signature += "`"
        lines << signature

        # Add @rubymap summary if present
        if method[:rubymap]
          lines << ""
          lines << "_#{method[:rubymap]}_"
        end

        # Method details
        details = []
        details << "**Visibility**: #{method[:visibility]}" if method[:visibility] != "public"
        details << "**Complexity**: #{method[:complexity]}" if method[:complexity] && method[:complexity] > 1
        details << "**Lines**: #{method[:lines]}" if method[:lines] && method[:lines] > 10

        if method[:location]
          details << "**Location**: `#{method[:location][:file]}:#{method[:location][:line]}`"
        end

        lines << details.join(" | ") unless details.empty?
        lines << ""

        lines.join("\n")
      end

      def format_parameter(param)
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
          param[:name]
        end
      end

      def format_classes(classes)
        lines = ["## Classes\n"]

        classes.each do |klass|
          lines << format_class(klass)
          lines << ""
        end

        lines.join("\n")
      end

      def format_class(klass)
        lines = []

        lines << "### #{klass[:fqname] || klass[:name]}"
        lines << "**Inherits from**: `#{klass[:superclass]}`" if klass[:superclass]
        lines << "**Namespace**: `#{klass[:namespace]}`" if klass[:namespace] && !klass[:namespace].empty?

        if klass[:mixins] && !klass[:mixins].empty?
          mixins = klass[:mixins].map { |m| "`#{m[:module]}`" }.join(", ")
          lines << "**Includes**: #{mixins}"
        end

        if @config[:include_metrics]
          metrics = []
          metrics << "Complexity: #{klass[:complexity]}" if klass[:complexity]
          metrics << "Cohesion: #{klass[:cohesion]&.round(2)}" if klass[:cohesion]
          metrics << "Fan-in: #{klass[:coupling][:fan_in]}" if klass[:coupling] && klass[:coupling][:fan_in]
          metrics << "Fan-out: #{klass[:coupling][:fan_out]}" if klass[:coupling] && klass[:coupling][:fan_out]

          lines << "**Metrics**: #{metrics.join(", ")}" unless metrics.empty?
        end

        if klass[:location]
          lines << "**Location**: `#{klass[:location][:file]}:#{klass[:location][:line]}`"
        end

        if klass[:methods] && !klass[:methods].empty?
          lines << ""
          lines << "**Methods** (#{klass[:methods].size}):"
          klass[:methods].each do |method|
            vis = (method[:visibility] == "public") ? "" : " (#{method[:visibility]})"
            complexity = (method[:complexity] && method[:complexity] > 5) ? " [complexity: #{method[:complexity]}]" : ""
            lines << "- `#{method[:name]}`#{vis}#{complexity}"
          end
        end

        if klass[:constants] && !klass[:constants].empty?
          lines << ""
          lines << "**Constants**:"
          klass[:constants].each do |const|
            lines << "- `#{const[:name]}` = `#{const[:value]}`"
          end
        end

        lines.join("\n")
      end

      def format_modules(modules)
        lines = ["## Modules\n"]

        modules.each do |mod|
          lines << format_module(mod)
          lines << ""
        end

        lines.join("\n")
      end

      def format_module(mod)
        lines = []

        lines << "### #{mod[:fqname] || mod[:name]}"
        lines << "**Namespace**: `#{mod[:namespace]}`" if mod[:namespace] && !mod[:namespace].empty?

        if mod[:included_in] && !mod[:included_in].empty?
          lines << "**Included in**: #{mod[:included_in].map { |c| "`#{c}`" }.join(", ")}"
        end

        if mod[:extended_in] && !mod[:extended_in].empty?
          lines << "**Extended in**: #{mod[:extended_in].map { |c| "`#{c}`" }.join(", ")}"
        end

        if mod[:location]
          lines << "**Location**: `#{mod[:location][:file]}:#{mod[:location][:line]}`"
        end

        if mod[:methods] && !mod[:methods].empty?
          lines << ""
          lines << "**Methods**:"
          mod[:methods].each do |method|
            vis = (method[:visibility] == "public") ? "" : " (#{method[:visibility]})"
            lines << "- `#{method[:name]}`#{vis}"
          end
        end

        lines.join("\n")
      end

      def format_relationships(relationships)
        lines = ["## Relationships\n"]

        if relationships[:inheritance_tree] && !relationships[:inheritance_tree].empty?
          lines << "### Inheritance Hierarchy"
          lines << "```"
          relationships[:inheritance_tree].each do |class_name, info|
            lines << if info[:parent]
              "#{class_name} < #{info[:parent]}"
            else
              class_name.to_s
            end
            info[:children].each do |child|
              lines << "  └── #{child}"
            end
          end
          lines << "```"
          lines << ""
        end

        if relationships[:dependencies] && !relationships[:dependencies].empty?
          lines << "### Dependencies"
          relationships[:dependencies].each do |class_name, deps|
            depends_on = deps[:depends_on] || []
            depended_by = deps[:depended_by] || []
            next if depends_on.empty? && depended_by.empty?

            lines << ""
            lines << "**#{class_name}**"
            lines << "- Depends on: #{depends_on.map { |d| "`#{d}`" }.join(", ")}" unless depends_on.empty?
            lines << "- Depended by: #{depended_by.map { |d| "`#{d}`" }.join(", ")}" unless depended_by.empty?
          end
          lines << ""
        end

        if relationships[:circular_dependencies] && !relationships[:circular_dependencies].empty?
          lines << "### ⚠️ Circular Dependencies"
          relationships[:circular_dependencies].each do |cycle|
            lines << "- #{cycle.join(" → ")}"
          end
          lines << ""
        end

        lines.join("\n")
      end

      def format_metrics(metrics)
        lines = ["## Quality Metrics\n"]

        if metrics[:complexity]
          lines << "### Complexity Analysis"

          if metrics[:complexity][:highest]
            lines << "- **Highest Complexity**: `#{metrics[:complexity][:highest][:method]}` (#{metrics[:complexity][:highest][:complexity]})"
          end

          if metrics[:complexity][:average]
            lines << "- **Average Complexity**: #{metrics[:complexity][:average]}"
          end

          if metrics[:complexity][:distribution]
            lines << ""
            lines << "**Distribution**:"
            metrics[:complexity][:distribution].each do |category, count|
              lines << "- #{category}: #{count} methods"
            end
          end

          lines << ""
        end

        if metrics[:coupling]
          lines << "### Coupling Analysis"

          if metrics[:coupling][:tightly_coupled] && !metrics[:coupling][:tightly_coupled].empty?
            lines << "**Tightly Coupled Classes**:"
            metrics[:coupling][:tightly_coupled].each do |item|
              lines << "- `#{item[:class]}` (coupling: #{item[:coupling]&.round(2)})"
            end
          end

          if metrics[:coupling][:loosely_coupled] && !metrics[:coupling][:loosely_coupled].empty?
            lines << ""
            lines << "**Loosely Coupled Classes**:"
            metrics[:coupling][:loosely_coupled].each do |item|
              lines << "- `#{item[:class]}` (coupling: #{item[:coupling]&.round(2)})"
            end
          end

          lines << ""
        end

        if metrics[:size]
          lines << "### Size Metrics"

          if metrics[:size][:largest_classes] && !metrics[:size][:largest_classes].empty?
            lines << "**Largest Classes**:"
            metrics[:size][:largest_classes].each do |item|
              lines << "- `#{item[:class]}`: #{item[:method_count]} methods"
            end
          end

          if metrics[:size][:longest_methods] && !metrics[:size][:longest_methods].empty?
            lines << ""
            lines << "**Longest Methods**:"
            metrics[:size][:longest_methods].each do |item|
              lines << "- `#{item[:method]}`: #{item[:lines]} lines"
            end
          end

          lines << ""
        end

        lines.join("\n")
      end

      def format_issues(issues)
        return "" if issues.nil? || issues.empty?

        lines = ["## Issues and Code Smells\n"]

        # Handle array format of issues
        if issues.is_a?(Array)
          issues.each do |issue|
            case issue[:type]
            when :high_complexity
              lines << "- High complexity: #{issue[:value]}"
            when :low_cohesion
              lines << "- Low cohesion: #{issue[:value]}"
            when :high_coupling
              lines << "- High coupling (fan-out): #{issue[:value]}"
            end
          end
          lines << ""
        elsif issues.is_a?(Hash) && issues[:low_cohesion] && !issues[:low_cohesion].empty?
          lines << "### Low Cohesion Classes"
          issues[:low_cohesion].each do |item|
            lines << "- `#{item[:class]}`: cohesion #{item[:cohesion]&.round(2)}"
          end
          lines << ""
        end

        if issues[:code_smells] && !issues[:code_smells].empty?
          lines << "### Code Smells"
          issues[:code_smells].each do |smell|
            lines << "- **#{smell[:type]}**: #{smell[:description]}"
          end
          lines << ""
        end

        if issues[:missing_references] && !issues[:missing_references].empty?
          lines << "### Missing References"
          issues[:missing_references].each do |ref|
            lines << "- `#{ref}`"
          end
          lines << ""
        end

        if issues[:circular_dependencies] && !issues[:circular_dependencies].empty?
          lines << "### Circular Dependencies"
          issues[:circular_dependencies].each do |cycle|
            lines << "- #{cycle.join(" → ")}"
          end
          lines << ""
        end

        lines.join("\n")
      end

      def format_patterns(patterns)
        return "" if patterns.values.all? { |v| v.nil? || v.empty? }

        lines = ["## Detected Patterns\n"]

        if patterns[:design_patterns] && !patterns[:design_patterns].empty?
          lines << "### Design Patterns"
          patterns[:design_patterns].each do |pattern|
            if pattern.is_a?(Hash)
              lines << "- **#{pattern[:type] || pattern["type"]}**: `#{pattern[:class] || pattern["class"]}`"
              lines << "  - Evidence: #{pattern[:evidence].join(", ")}" if pattern[:evidence]
            elsif pattern.respond_to?(:pattern)
              lines << "- **#{pattern.pattern}**: `#{pattern.class_name}`"
              lines << "  - Evidence: #{pattern.evidence.join(", ")}" if pattern.respond_to?(:evidence) && pattern.evidence
            end
          end
          lines << ""
        end

        if patterns[:ruby_idioms] && !patterns[:ruby_idioms].empty?
          lines << "### Ruby Idioms"
          patterns[:ruby_idioms].each do |idiom|
            if idiom.respond_to?(:idiom)
              # It's a RubyIdiom struct
              location = (idiom.respond_to?(:class) && idiom.respond_to?(:method)) ? "#{idiom.class}##{idiom.method}" : "unknown"
              lines << "- **#{idiom.idiom}**: `#{location}`"
            elsif idiom.is_a?(Hash)
              lines << "- **#{idiom[:type] || idiom["type"]}**: `#{idiom[:location] || idiom["location"]}`"
            end
          end
          lines << ""
        end

        if patterns[:rails_patterns] && !patterns[:rails_patterns].empty?
          lines << "### Rails Patterns"
          patterns[:rails_patterns].each do |pattern|
            if pattern.is_a?(Hash)
              lines << "- **#{pattern[:type] || pattern["type"]}**: `#{pattern[:class] || pattern["class"]}`"
            elsif pattern.respond_to?(:pattern_type)
              lines << "- **#{pattern.pattern_type}**: `#{pattern.class_name}`"
            end
          end
          lines << ""
        end

        lines.join("\n")
      end
    end
  end
end
