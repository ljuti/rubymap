# frozen_string_literal: true

module Rubymap
  # Adapts an Extractor::Result to the hash format expected by the pipeline.
  #
  # Provides a typed contract for the conversion, replacing the ad-hoc
  # safe-navigation mapping in Pipeline#merge_result! with explicit
  # field extraction. Each entity type (class, module, method, constant)
  # is mapped through a dedicated private method.
  #
  # @example
  #   result = extractor.extract_from_file("app/models/user.rb")
  #   hash = ResultAdapter.adapt(result)
  #   hash[:classes]  # => [{name: "User", type: "class", ...}]
  class ResultAdapter
    # Converts an Extractor::Result to the pipeline hash format.
    #
    # @param result [Extractor::Result] The extraction result
    # @return [Hash] Hash with :classes, :modules, :methods, :constants
    def self.adapt(result)
      new(result).adapt
    end

    def initialize(result)
      @result = result
    end

    def adapt
      {
        classes: adapt_classes,
        modules: adapt_modules,
        methods: adapt_methods,
        constants: adapt_constants,
        mixins: adapt_mixins,
        attributes: adapt_attributes,
        dependencies: adapt_dependencies,
        patterns: adapt_patterns,
        class_variables: adapt_class_variables,
        aliases: adapt_aliases,
        method_calls: adapt_method_calls
      }
    end

    private

    def adapt_classes
      (@result.classes || []).map { |c| class_hash(c) }
    end

    def adapt_modules
      (@result.modules || []).map { |m| module_hash(m) }
    end

    def adapt_methods
      (@result.methods || []).map { |m| method_hash(m) }
    end

    def adapt_constants
      (@result.constants || []).map { |c| constant_hash(c) }
    end

    def adapt_mixins
      (@result.mixins || []).map { |m| mixin_hash(m) }
    end

    def adapt_attributes
      (@result.attributes || []).map { |a| attribute_hash(a) }
    end

    def adapt_dependencies
      (@result.dependencies || []).map { |d| dependency_hash(d) }
    end

    def adapt_patterns
      (@result.patterns || []).map { |p| pattern_hash(p) }
    end

    def adapt_class_variables
      (@result.class_variables || []).map { |cv| class_variable_hash(cv) }
    end

    def adapt_aliases
      (@result.aliases || []).map { |a| alias_hash(a) }
    end

    def adapt_method_calls
      (@result.methods || []).flat_map { |m| method_call_hashes(m) }
    end

    def class_hash(class_info)
      {
        name: class_info.name,
        type: class_info.type,
        superclass: class_info.superclass,
        file: @result.file_path,
        line: location_line(class_info.location),
        namespace: class_info.namespace,
        documentation: class_info.doc
      }
    end

    def module_hash(mod_info)
      {
        name: mod_info.name,
        type: "module",
        file: @result.file_path,
        line: location_line(mod_info.location),
        namespace: mod_info.namespace,
        documentation: mod_info.doc
      }
    end

    def method_hash(method_info)
      {
        name: method_info.name,
        scope: method_info.scope,
        visibility: method_info.visibility,
        receiver_type: method_info.receiver_type,
        params: method_info.params,
        file: @result.file_path,
        line: location_line(method_info.location),
        namespace: method_info.namespace,
        owner: method_info.owner,
        documentation: method_info.doc,
        calls_made: method_info.calls_made,
        branches: method_info.branches,
        loops: method_info.loops,
        conditionals: method_info.conditionals,
        body_lines: method_info.body_lines
      }
    end

    def constant_hash(const_info)
      {
        name: const_info.name,
        value: const_info.value,
        file: @result.file_path,
        line: location_line(const_info.location),
        namespace: const_info.namespace,
        documentation: const_info.respond_to?(:doc) ? const_info.doc : nil
      }
    end

    def mixin_hash(mixin_info)
      {
        type: mixin_info.type,
        module_name: mixin_info.module_name,
        target: mixin_info.target,
        file: @result.file_path,
        line: location_line(mixin_info.location)
      }
    end

    def attribute_hash(attr_info)
      {
        name: attr_info.name,
        type: attr_info.type,
        file: @result.file_path,
        line: location_line(attr_info.location),
        namespace: attr_info.namespace
      }
    end

    def dependency_hash(dep_info)
      {
        type: dep_info.type,
        path: dep_info.path,
        file: @result.file_path,
        line: location_line(dep_info.location),
        constant: dep_info.constant
      }
    end

    def pattern_hash(pattern_info)
      {
        type: pattern_info.type,
        target: pattern_info.target,
        method: pattern_info.method,
        file: @result.file_path,
        line: location_line(pattern_info.location),
        indicators: pattern_info.indicators
      }
    end

    def class_variable_hash(cv_info)
      {
        name: cv_info.name,
        file: @result.file_path,
        line: location_line(cv_info.location),
        namespace: cv_info.namespace,
        initial_value: cv_info.initial_value
      }
    end

    def alias_hash(alias_info)
      {
        new_name: alias_info.new_name,
        original_name: alias_info.original_name,
        file: @result.file_path,
        line: location_line(alias_info.location),
        namespace: alias_info.namespace
      }
    end

    def method_call_hashes(method_info)
      (method_info.calls_made || []).map do |call|
        from = "#{method_info.owner}##{method_info.name}"
        from = "#{method_info.owner}.#{method_info.name}" if method_info.scope == "class"
        to = build_call_target(call)
        {from: from, to: to, type: "method_call"}
      end
    end

    def build_call_target(call)
      receiver = call[:receiver] || call["receiver"]
      method = call[:method] || call["method"]
      if receiver.is_a?(Array) && !receiver.empty?
        "#{receiver.join(".")}.#{method}"
      elsif method
        method.to_s
      else
        "unknown"
      end
    end

    def location_line(location)
      location&.start_line
    end
  end
end
