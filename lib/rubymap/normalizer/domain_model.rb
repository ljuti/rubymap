# frozen_string_literal: true

module Rubymap
  class Normalizer
    # Core domain model with clean separation of concerns
    # Uses Value Objects pattern to encapsulate behavior and ensure immutability

    # Simplified core normalized structures focused on essential data
    NormalizedSymbol = Struct.new(
      :symbol_id, :name, :fqname, :location, :namespace_path, :provenance,
      keyword_init: true
    ) do
      def initialize(**args)
        super
        # Note: Not freezing to allow resolvers to modify
      end
    end

    # Core class structure without testing/analysis pollution
    CoreNormalizedClass = Struct.new(
      :symbol_id, :name, :fqname, :kind, :superclass, :location,
      :namespace_path, :children, :inheritance_chain,
      :instance_methods, :class_methods,
      :available_instance_methods, :available_class_methods,
      :mixins, :provenance, :doc, :rubymap,
      keyword_init: true
    ) do
      def initialize(**args)
        # Set sensible defaults
        args[:kind] ||= "class"
        args[:children] ||= []
        args[:inheritance_chain] ||= []
        args[:instance_methods] ||= []
        args[:class_methods] ||= []
        args[:available_instance_methods] ||= []
        args[:available_class_methods] ||= []
        args[:mixins] ||= []
        super
        # Note: Not freezing to allow resolvers to modify
      end

      def has_superclass?
        !superclass.nil? && !superclass.empty?
      end

      def has_mixins?
        !mixins.empty?
      end
    end

    CoreNormalizedModule = Struct.new(
      :symbol_id, :name, :fqname, :kind, :location,
      :namespace_path, :children, :provenance, :doc,
      keyword_init: true
    ) do
      def initialize(**args)
        args[:kind] ||= "module"
        args[:children] ||= []
        super
        # Note: Not freezing to allow resolvers to modify
      end
    end

    CoreNormalizedMethod = Struct.new(
      :symbol_id, :name, :fqname, :visibility, :owner, :scope,
      :parameters, :arity, :canonical_name, :available_in,
      :inferred_visibility, :source, :provenance, :doc, :rubymap,
      keyword_init: true
    ) do
      def initialize(**args)
        args[:visibility] ||= "public"
        args[:scope] ||= "instance"
        args[:parameters] ||= []
        args[:arity] ||= 0
        args[:available_in] ||= []
        super
        # Note: Not freezing to allow resolvers to modify
      end

      def class_method?
        scope == "class"
      end

      def instance_method?
        scope == "instance"
      end

      def public?
        visibility == "public"
      end
    end

    # Method call structure
    CoreNormalizedMethodCall = Struct.new(
      :from, :to, :type,
      keyword_init: true
    ) do
      def initialize(**args)
        args[:type] ||= "method_call"
        super
        # Note: Not freezing to allow modifications
      end
    end

    # Location value object
    Location = Struct.new(:file, :line, keyword_init: true) do
      def initialize(**args)
        super
        freeze
      end

      def valid?
        !file.nil?
      end

      def to_s
        "#{file}:#{line}"
      end
    end

    # Provenance value object
    ProvenanceInfo = Struct.new(
      :sources, :confidence, :timestamp,
      keyword_init: true
    ) do
      def initialize(**args)
        args[:sources] = Array(args[:sources])
        args[:confidence] ||= 0.5
        args[:timestamp] ||= Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
        super
        freeze
      end

      def high_confidence?
        confidence >= 0.8
      end

      def primary_source
        sources.first
      end
    end

    # Method parameter value object
    Parameter = Struct.new(:name, :type, :default_value, keyword_init: true) do
      def initialize(**args)
        super
        freeze
      end

      def required?
        type == "required" || type == "req"
      end

      def optional?
        type == "optional" || type == "opt"
      end

      def rest?
        type == "rest"
      end
    end
  end
end
