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
        constants: adapt_constants
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
        documentation: method_info.doc
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

    def location_line(location)
      location&.start_line
    end
  end
end
