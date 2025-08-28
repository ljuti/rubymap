# frozen_string_literal: true

require 'digest'
require 'set'

module Rubymap
  # Normalizes extracted Ruby symbols into a consistent format
  # Handles deduplication, namespace resolution, and data standardization
  class Normalizer
    # Schema version for normalized output
    SCHEMA_VERSION = 1
    
    # Normalizer version for tracking changes
    NORMALIZER_VERSION = "1.0.0"
    
    # Data source types for provenance tracking
    DATA_SOURCES = {
      static: "static",
      runtime: "runtime", 
      yard: "yard",
      rbs: "rbs",
      sorbet: "sorbet",
      inferred: "inferred"
    }.freeze
    
    # Precedence order (higher number = higher precedence)
    SOURCE_PRECEDENCE = {
      DATA_SOURCES[:inferred] => 1,
      DATA_SOURCES[:yard] => 2,
      DATA_SOURCES[:sorbet] => 3,
      DATA_SOURCES[:rbs] => 4,
      DATA_SOURCES[:runtime] => 5,
      DATA_SOURCES[:static] => 6
    }.freeze
    def initialize
      @symbol_id_generator = SymbolIdGenerator.new
      @provenance_tracker = ProvenanceTracker.new
    end

    # Main normalization method
    def normalize(raw_data)
      @errors = []
      @symbol_index = {}
      
      result = NormalizedResult.new(
        schema_version: SCHEMA_VERSION,
        normalizer_version: NORMALIZER_VERSION,
        normalized_at: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
      )
      
      # Process each type of symbol in deterministic order
      process_classes(raw_data[:classes] || [], result)
      process_modules(raw_data[:modules] || [], result) 
      process_methods(raw_data[:methods] || [], result)
      process_method_calls(raw_data[:method_calls] || [], result)
      process_mixins(raw_data[:mixins] || [], result)
      
      # Build relationships and resolve references
      build_namespace_hierarchies(result)
      resolve_inheritance_chains(result)
      resolve_cross_references(result)
      resolve_mixin_methods(result)
      deduplicate_symbols(result)
      
      # Ensure deterministic output ordering
      ensure_deterministic_output(result)
      
      # Copy errors to result
      result.errors = @errors
      
      result
    end
    
    private
    
    def process_classes(classes, result)
      classes.each do |class_data|
        next unless validate_class_data(class_data)
        
        # Check if it's actually a module
        if class_data[:type] == "module" || class_data[:kind] == "module"
          normalized = normalize_module(class_data)
          result.modules << normalized
        else
          normalized = normalize_class(class_data)
          result.classes << normalized
          
          # Handle mixins if present
          if class_data[:mixins]
            class_data[:mixins].each do |mixin|
              @mixins ||= []
              @mixins << {target: normalized.fqname, **mixin}
            end
          end
        end
        
        index_symbol(normalized)
      end
    end
    
    def process_modules(modules, result)
      modules.each do |module_data|
        next unless validate_module_data(module_data)
        
        # Modules can be represented as classes with type "module"
        normalized = normalize_module(module_data)
        result.modules << normalized
        index_symbol(normalized)
      end
    end
    
    def process_methods(methods, result)
      methods.each do |method_data|
        next unless validate_method_data(method_data)
        
        normalized = normalize_method(method_data)
        result.methods << normalized
      end
    end
    
    def process_method_calls(method_calls, result)
      method_calls.each do |call_data|
        normalized = normalize_method_call(call_data)
        result.method_calls << normalized if normalized
      end
    end
    
    def process_mixins(mixins, result)
      # Process module inclusions from raw data or accumulated mixins
      mixins_to_process = mixins + (@mixins || [])
      
      mixins_to_process.each do |mixin_data|
        target_class = find_symbol(mixin_data[:target], result)
        next unless target_class
        
        target_class.mixins ||= []
        target_class.mixins << {
          type: mixin_data[:type],
          module: mixin_data[:module]
        }
      end
    end
    
    def normalize_class(data)
      fqname = generate_fqname(data[:name], data[:namespace])
      symbol_id = @symbol_id_generator.generate_class_id(fqname, data[:type] || "class")
      
      provenance = @provenance_tracker.create_provenance(
        sources: [data[:source] || DATA_SOURCES[:inferred]],
        confidence: calculate_confidence(data)
      )
      
      NormalizedClass.new(
        symbol_id: symbol_id,
        name: data[:name],
        fqname: fqname,
        kind: data[:type] || "class",
        superclass: data[:superclass],
        location: normalize_location(data[:location]),
        namespace_path: extract_namespace_path(data[:name]),
        children: [],
        inheritance_chain: [],
        instance_methods: [],
        class_methods: [],
        available_instance_methods: [],
        available_class_methods: [],
        provenance: provenance
      )
    end
    
    def normalize_module(data)
      fqname = generate_fqname(data[:name], data[:namespace])
      symbol_id = @symbol_id_generator.generate_module_id(fqname)
      
      provenance = @provenance_tracker.create_provenance(
        sources: [data[:source] || DATA_SOURCES[:inferred]],
        confidence: calculate_confidence(data)
      )
      
      NormalizedModule.new(
        symbol_id: symbol_id,
        name: data[:name],
        fqname: fqname,
        kind: "module",
        location: normalize_location(data[:location]),
        namespace_path: extract_namespace_path(data[:name]),
        children: [],
        provenance: provenance
      )
    end
    
    def normalize_method(data)
      owner = data[:class] || data[:owner]
      scope = determine_method_scope(data)
      fqname = generate_method_fqname(data[:name], owner, scope)
      
      normalized_params = normalize_parameters(data[:parameters])
      arity = calculate_arity(normalized_params)
      
      symbol_id = @symbol_id_generator.generate_method_id(
        fqname: fqname,
        receiver: scope == "class" ? "class" : "instance", 
        arity: arity
      )
      
      visibility = normalize_visibility(data[:visibility])
      inferred = infer_visibility_from_name(data[:name])
      
      provenance = @provenance_tracker.create_provenance(
        sources: [data[:source] || DATA_SOURCES[:inferred]],
        confidence: calculate_confidence(data)
      )
      
      NormalizedMethod.new(
        symbol_id: symbol_id,
        name: data[:name],
        fqname: fqname,
        visibility: visibility,
        owner: owner,
        scope: scope,
        parameters: normalized_params,
        arity: arity,
        canonical_name: to_snake_case(data[:name]),
        available_in: [],
        inferred_visibility: inferred,
        source: data[:source] || owner,
        provenance: provenance
      )
    end
    
    def normalize_method_call(data)
      return nil unless data[:caller] && data[:calls]
      
      target = resolve_method_call_target(data[:calls], data[:caller])
      call_type = determine_call_type(data[:calls], target)
      
      NormalizedMethodCall.new(
        from: data[:caller],
        to: target,
        type: call_type
      )
    end
    
    def normalize_location(location)
      return nil unless location
      
      NormalizedLocation.new(
        file: location[:file] || location["file"],
        line: (location[:line] || location["line"]).to_i
      )
    end
    
    def normalize_visibility(visibility)
      case visibility
      when :public, "public" then "public"
      when :private, "private" then "private"
      when :protected, "protected" then "protected"
      when nil then "public"  # Handle missing visibility
      else
        # Invalid visibility type
        unless visibility.is_a?(String) || visibility.is_a?(Symbol)
          add_validation_error("invalid visibility: #{visibility}", {visibility: visibility})
        end
        "public"
      end
    end
    
    def infer_visibility_from_name(name)
      return "private" if name.to_s.start_with?("_")
      "public"
    end
    
    def normalize_parameters(params)
      return [] unless params
      
      params.map do |param|
        case param
        when String
          {name: param, type: "required"}
        when Hash
          param
        else
          {name: param.to_s, type: "required"}
        end
      end
    end
    
    def generate_fqname(name, namespace = nil)
      return name unless namespace && !namespace.empty?
      "#{namespace}::#{name}"
    end
    
    def generate_method_fqname(method_name, owner, scope)
      return method_name unless owner
      
      separator = scope == "class" ? "." : "#"
      "#{owner}#{separator}#{method_name}"
    end
    
    def extract_namespace_path(name)
      return [] unless name.include?("::")
      
      parts = name.split("::")
      parts[0...-1]
    end
    
    def determine_method_scope(data)
      return data[:scope] if data[:scope]
      
      # Infer from method name or other indicators
      "instance"
    end
    
    def determine_call_type(call_target, resolved_target = nil)
      case call_target
      when "super"
        "super_call"
      when /^[A-Z]/
        "class_method_call"
      when /^@/
        "instance_variable_access"
      else
        # Check if it's calling a private method
        if resolved_target && resolved_target =~ /#(validate_|_)/
          "private_method_call"
        else
          "instance_method_call"
        end
      end
    end
    
    def resolve_method_call_target(target, caller_context)
      if target == "super"
        # For super calls, resolve to parent method
        if caller_context =~ /^(.+)(#|\.)(.+)$/
          class_name = $1
          method_name = $3
          
          # Find parent class and construct target
          parent = find_parent_class(class_name)
          return "#{parent}##{method_name}" if parent
        end
        target
      elsif target !~ /#|\./
        # If it's just a method name, append it to the caller's class
        if caller_context =~ /^(.+)(#|\.)/
          class_name = $1
          "#{class_name}##{target}"
        else
          target
        end
      else
        target
      end
    end
    
    def find_parent_class(class_name)
      symbol = @symbol_index[class_name]
      return nil unless symbol && symbol.respond_to?(:superclass)
      
      symbol.superclass
    end
    
    def to_snake_case(name)
      name.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
    end
    
    def calculate_arity(parameters)
      return 0 unless parameters
      
      required = parameters.count { |p| p[:type] == "required" || p[:type] == "req" }
      optional = parameters.count { |p| p[:type] == "optional" || p[:type] == "opt" }
      rest = parameters.any? { |p| p[:type] == "rest" }
      
      rest ? -required - 1 : required + optional
    end
    
    def calculate_confidence(data)
      source = data[:source] || DATA_SOURCES[:inferred]
      base_confidence = case source
      when DATA_SOURCES[:rbs] then 0.95
      when DATA_SOURCES[:sorbet] then 0.90
      when DATA_SOURCES[:yard] then 0.80
      when DATA_SOURCES[:runtime] then 0.85
      when DATA_SOURCES[:static] then 0.75
      else 0.50 # inferred
      end
      
      # Boost confidence if location information is available
      base_confidence += 0.05 if data[:location]
      
      # Reduce confidence if key information is missing
      base_confidence -= 0.10 if data[:name].nil? || data[:name].empty?
      
      [base_confidence, 1.0].min
    end
    
    def ensure_deterministic_output(result)
      # Sort all collections by stable criteria
      result.classes.sort_by! { |c| [c.fqname, c.symbol_id] }
      result.modules.sort_by! { |m| [m.fqname, m.symbol_id] }
      result.methods.sort_by! { |m| [m.fqname, m.symbol_id] }
      result.method_calls.sort_by! { |mc| [mc.from, mc.to] }
      
      # Sort nested collections
      result.classes.each do |klass|
        klass.children.sort! if klass.children
        klass.instance_methods.sort! if klass.instance_methods
        klass.class_methods.sort! if klass.class_methods
        klass.available_instance_methods.sort! if klass.available_instance_methods
        klass.available_class_methods.sort! if klass.available_class_methods
      end
      
      result.modules.each do |mod|
        mod.children.sort! if mod.children
      end
      
      result.methods.each do |method|
        method.available_in.sort! if method.available_in
      end
    end
    
    def build_namespace_hierarchies(result)
      # Group by namespace levels
      all_symbols = result.classes + result.modules
      
      all_symbols.each do |symbol|
        next unless symbol.fqname.include?("::")
        
        parent_name = symbol.namespace_path.join("::")
        parent = all_symbols.find { |s| s.fqname == parent_name }
        
        if parent
          parent.children << symbol.fqname
        end
      end
    end
    
    def resolve_inheritance_chains(result)
      result.classes.each do |klass|
        chain = build_inheritance_chain(klass, result.classes)
        klass.inheritance_chain = chain
      end
    end
    
    def build_inheritance_chain(klass, all_classes)
      chain = [klass.fqname]
      current = klass
      
      while current.superclass
        chain << current.superclass
        current = all_classes.find { |c| c.fqname == current.superclass }
        break unless current
      end
      
      chain
    end
    
    def resolve_cross_references(result)
      # Associate methods with their owner classes
      result.methods.each do |method|
        owner = find_symbol(method.owner, result)
        next unless owner
        
        if method.scope == "class"
          owner.class_methods << method.name if owner.respond_to?(:class_methods)
        else
          owner.instance_methods << method.name if owner.respond_to?(:instance_methods)
        end
        
        # Track availability through inheritance
        track_method_availability(method, owner, result)
      end
    end
    
    def resolve_mixin_methods(result)
      # Resolve methods from included/extended modules
      result.classes.each do |klass|
        next unless klass.respond_to?(:mixins) && klass.mixins
        
        klass.mixins.each do |mixin|
          module_obj = find_symbol(mixin[:module], result)
          next unless module_obj
          
          # Find methods from the mixed-in module
          module_methods = result.methods.select { |m| m.owner == mixin[:module] }
          
          module_methods.each do |method|
            if mixin[:type] == "include"
              # Include adds instance methods from module
              # And class methods from module are also made available
              if method.scope == "instance"
                klass.available_instance_methods << method.name
                method.available_in << klass.fqname unless method.available_in.include?(klass.fqname)
              elsif method.scope == "class"
                # Module class methods become available as class methods on the including class
                klass.available_class_methods << method.name
                method.available_in << klass.fqname unless method.available_in.include?(klass.fqname)
              end
            elsif mixin[:type] == "extend"
              # Extend adds module's instance methods as class methods
              if method.scope == "instance"
                klass.available_class_methods << method.name
                method.available_in << klass.fqname unless method.available_in.include?(klass.fqname)
              elsif method.scope == "class"
                # Module's class methods also become class methods
                klass.available_class_methods << method.name
                method.available_in << klass.fqname unless method.available_in.include?(klass.fqname)
              end
            end
          end
        end
      end
    end
    
    def track_method_availability(method, owner, result)
      # Add to available_in for the owner and all descendants
      method.available_in << owner.fqname
      
      # Find all classes that inherit from owner
      result.classes.each do |klass|
        if klass.inheritance_chain.include?(owner.fqname)
          if method.scope == "class"
            klass.available_class_methods << method.name
          else
            klass.available_instance_methods << method.name
          end
          
          method.available_in << klass.fqname unless method.available_in.include?(klass.fqname)
        end
      end
    end
    
    def deduplicate_symbols(result)
      # Merge duplicate methods with precedence rules
      result.methods = deduplicate_and_merge_methods(result.methods)
      
      # Merge duplicate classes/modules with precedence rules
      result.classes = deduplicate_and_merge_classes(result.classes)
      result.modules = deduplicate_and_merge_modules(result.modules)
    end
    
    def deduplicate_by_signature(methods)
      seen = Set.new
      methods.reject do |method|
        signature = "#{method.owner}##{method.name}"
        if seen.include?(signature)
          true
        else
          seen.add(signature)
          false
        end
      end
    end
    
    def deduplicate_by_fqname(symbols)
      seen = Set.new
      symbols.reject do |symbol|
        if seen.include?(symbol.fqname)
          true
        else
          seen.add(symbol.fqname)
          false
        end
      end
    end
    
    def deduplicate_and_merge_methods(methods)
      grouped = methods.group_by(&:symbol_id)
      
      grouped.map do |symbol_id, method_group|
        if method_group.size == 1
          method_group.first
        else
          merge_methods_with_precedence(method_group)
        end
      end
    end
    
    def deduplicate_and_merge_classes(classes)
      grouped = classes.group_by(&:symbol_id)
      
      grouped.map do |symbol_id, class_group|
        if class_group.size == 1
          class_group.first
        else
          merge_classes_with_precedence(class_group)
        end
      end
    end
    
    def deduplicate_and_merge_modules(modules)
      grouped = modules.group_by(&:symbol_id)
      
      grouped.map do |symbol_id, module_group|
        if module_group.size == 1
          module_group.first
        else
          merge_modules_with_precedence(module_group)
        end
      end
    end
    
    def merge_methods_with_precedence(methods)
      # Sort by precedence (highest first)
      sorted_methods = methods.sort_by { |m| -get_highest_source_precedence(m.provenance) }
      primary = sorted_methods.first
      
      # Merge provenance from all sources
      merged_provenance = methods.reduce(primary.provenance) do |acc, method|
        @provenance_tracker.merge_provenance(acc, method.provenance)
      end
      
      # Use primary method as base, but update with merged provenance
      primary.dup.tap do |merged|
        merged.provenance = merged_provenance
        # Take most restrictive visibility if explicitly set
        merged.visibility = get_most_restrictive_visibility(methods)
      end
    end
    
    def merge_classes_with_precedence(classes)
      # Sort by precedence (highest first)
      sorted_classes = classes.sort_by { |c| -get_highest_source_precedence(c.provenance) }
      primary = sorted_classes.first
      
      # Merge provenance from all sources
      merged_provenance = classes.reduce(primary.provenance) do |acc, klass|
        @provenance_tracker.merge_provenance(acc, klass.provenance)
      end
      
      # Use primary class as base, but update with merged provenance
      primary.dup.tap do |merged|
        merged.provenance = merged_provenance
        # Merge superclass information (prefer explicit over inferred)
        merged.superclass = get_most_reliable_superclass(classes)
      end
    end
    
    def merge_modules_with_precedence(modules)
      # Sort by precedence (highest first)  
      sorted_modules = modules.sort_by { |m| -get_highest_source_precedence(m.provenance) }
      primary = sorted_modules.first
      
      # Merge provenance from all sources
      merged_provenance = modules.reduce(primary.provenance) do |acc, mod|
        @provenance_tracker.merge_provenance(acc, mod.provenance)
      end
      
      # Use primary module as base, but update with merged provenance
      primary.dup.tap do |merged|
        merged.provenance = merged_provenance
      end
    end
    
    def get_highest_source_precedence(provenance)
      return 0 unless provenance && provenance.sources
      
      provenance.sources.map { |source| SOURCE_PRECEDENCE[source] || 0 }.max
    end
    
    def get_most_restrictive_visibility(methods)
      visibilities = methods.map(&:visibility).compact.uniq
      
      # Order by restrictiveness: private > protected > public
      if visibilities.include?("private")
        "private"
      elsif visibilities.include?("protected")
        "protected"
      else
        "public"
      end
    end
    
    def get_most_reliable_superclass(classes)
      superclasses = classes.map(&:superclass).compact.uniq
      return nil if superclasses.empty?
      
      # Prefer superclass from highest precedence source
      classes.sort_by { |c| -get_highest_source_precedence(c.provenance) }
             .find(&:superclass)&.superclass
    end
    
    def find_symbol(name, result)
      result.classes.find { |c| c.fqname == name || c.name == name } ||
      result.modules.find { |m| m.fqname == name || m.name == name }
    end
    
    def index_symbol(symbol)
      @symbol_index[symbol.fqname] = symbol
      @symbol_index[symbol.name] = symbol unless symbol.fqname == symbol.name
    end
    
    def validate_class_data(data)
      if data[:name].nil?
        add_validation_error("missing required field: name", data)
        return false
      end
      true
    end
    
    def validate_module_data(data)
      if data[:name].nil?
        add_validation_error("missing required field: name", data)
        return false
      end
      true
    end
    
    def validate_method_data(data)
      if data[:name].nil?
        add_validation_error("missing required field: name", data)
        return false
      end
      true
    end
    
    def add_validation_error(message, data)
      error = NormalizedError.new(
        type: "validation",
        message: message,
        data: data
      )
      @errors << error
    end
    
    # Symbol ID generator using Strategy pattern
    class SymbolIdGenerator
      def generate_class_id(fqname, kind = "class")
        generate_id("c", fqname, kind)
      end
      
      def generate_module_id(fqname)
        generate_id("m", fqname, "module")
      end
      
      def generate_method_id(fqname:, receiver:, arity:)
        generate_id("m", fqname, receiver, arity.to_s)
      end
      
      private
      
      def generate_id(*components)
        content = components.compact.join("/")
        Digest::SHA256.hexdigest(content)[0..15] # Use first 16 characters for shorter IDs
      end
    end
    
    # Provenance tracking for data sources and confidence
    class ProvenanceTracker
      def create_provenance(sources:, confidence: 0.5)
        Provenance.new(
          sources: Array(sources),
          confidence: confidence,
          timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
        )
      end
      
      def merge_provenance(existing, new_provenance)
        merged_sources = (existing.sources + new_provenance.sources).uniq
        highest_confidence = [existing.confidence, new_provenance.confidence].max
        
        Provenance.new(
          sources: merged_sources,
          confidence: highest_confidence,
          timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
        )
      end
    end
    
    # Result object to hold normalized data
    class NormalizedResult
      attr_accessor :classes, :modules, :methods, :method_calls, :errors, 
                    :schema_version, :normalizer_version, :normalized_at
      
      def initialize(schema_version: nil, normalizer_version: nil, normalized_at: nil)
        @classes = []
        @modules = []
        @methods = []
        @method_calls = []
        @errors = []
        @schema_version = schema_version
        @normalizer_version = normalizer_version
        @normalized_at = normalized_at
      end
    end
    
    # Provenance information for tracking data sources
    Provenance = Struct.new(
      :sources, :confidence, :timestamp,
      keyword_init: true
    )
    
    # Error structure for validation
    NormalizedError = Struct.new(
      :type, :message, :data,
      keyword_init: true
    )
    
    # Normalized data structures with provenance and symbol IDs
    NormalizedClass = Struct.new(
      :symbol_id, :name, :fqname, :kind, :superclass, :location, 
      :namespace_path, :children, :inheritance_chain,
      :instance_methods, :class_methods,
      :available_instance_methods, :available_class_methods,
      :mixins, :provenance,
      keyword_init: true
    )
    
    NormalizedModule = Struct.new(
      :symbol_id, :name, :fqname, :kind, :location, 
      :namespace_path, :children, :provenance,
      keyword_init: true
    )
    
    NormalizedMethod = Struct.new(
      :symbol_id, :name, :fqname, :visibility, :owner, :scope,
      :parameters, :arity, :canonical_name, :available_in,
      :inferred_visibility, :source, :provenance,
      keyword_init: true
    )
    
    NormalizedMethodCall = Struct.new(
      :from, :to, :type,
      keyword_init: true
    )
    
    NormalizedLocation = Struct.new(
      :file, :line,
      keyword_init: true
    )
  end
end