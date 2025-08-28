# frozen_string_literal: true

require "prism"
require "ostruct"

module Rubymap
  # Extracts symbols and metadata from Ruby source code using static analysis
  class Extractor
    # Result object containing extracted symbols and metadata
    class Result
      attr_accessor :classes, :modules, :methods, :constants, :attributes, :mixins,
                   :dependencies, :patterns, :class_variables, :aliases, :errors, :file_path
      
      def initialize
        @classes = []
        @modules = []
        @methods = []
        @constants = []
        @attributes = []
        @mixins = []
        @dependencies = []
        @patterns = []
        @class_variables = []
        @aliases = []
        @errors = []
        @file_path = nil
      end
    end

    # Information structures with behavior
    class ClassInfo
      attr_accessor :name, :type, :superclass, :location, :doc, :documentation
      
      def initialize(name:, type: "class", superclass: nil, location: nil, doc: nil)
        @name = name
        @type = type
        @superclass = superclass
        @location = location
        @doc = doc
        @documentation = doc
      end
    end
    
    class ModuleInfo
      attr_accessor :name, :type, :location, :doc, :documentation
      
      def initialize(name:, location: nil, doc: nil)
        @name = name
        @type = "module"
        @location = location
        @doc = doc
        @documentation = doc
      end
    end
    
    class MethodInfo
      attr_accessor :name, :visibility, :receiver_type, :scope, :params, :parameters, :location, :doc
      
      def initialize(name:, visibility: "public", receiver_type: "instance", params: [], location: nil, doc: nil)
        @name = name
        @visibility = visibility
        @receiver_type = receiver_type
        @scope = receiver_type
        @params = params
        @parameters = params
        @location = location
        @doc = doc
      end
    end
    
    class ConstantInfo
      attr_accessor :name, :value, :type, :location
      
      def initialize(name:, value: nil, location: nil)
        @name = name
        @value = value
        @type = infer_type(value)
        @location = location
      end
      
      private
      
      def infer_type(value)
        case value
        when /^\[.*\]$/ then "array"
        when /^\{.*\}$/ then "hash"
        when /^".*"$/ then "string"
        when /^\d+$/ then "integer"
        else "unknown"
        end
      end
    end
    
    class AttributeInfo
      attr_accessor :name, :type, :location
      
      def initialize(name:, type:, location: nil)
        @name = name
        @type = type
        @location = location
      end
    end
    
    class MixinInfo
      attr_accessor :type, :module_name, :module, :target, :location
      
      def initialize(type:, module_name:, target: nil, location: nil)
        @type = type
        @module_name = module_name
        @module = module_name  # Alias for compatibility
        @target = target
        @location = location
      end
    end
    
    class DependencyInfo
      attr_accessor :type, :name, :path, :constant, :external
      
      def initialize(type:, name: nil, path: nil, constant: nil, external: false)
        @type = type
        @name = name
        @path = path
        @constant = constant
        @external = external
      end
    end
    
    class PatternInfo
      attr_accessor :type, :indicators
      
      def initialize(type:, indicators: [])
        @type = type
        @indicators = indicators
      end
    end
    
    class ClassVariableInfo
      attr_accessor :name, :initial_value
      
      def initialize(name:, initial_value: nil)
        @name = name
        @initial_value = initial_value
      end
    end
    
    class AliasInfo
      attr_accessor :new_name, :original_name
      
      def initialize(new_name:, original_name:)
        @new_name = new_name
        @original_name = original_name
      end
    end

    def initialize
      @context = ExtractionContext.new
      @node_visitor = NodeVisitor.new(@context)
    end
    
    # Context for maintaining state during extraction
    class ExtractionContext
      attr_accessor :current_visibility, :current_namespace, :result, :code_lines
      
      def initialize
        @current_visibility = :public
        @current_namespace = []
        @result = Result.new
        @code_lines = []
      end
      
      def push_namespace(name)
        @current_namespace.push(name)
      end
      
      def pop_namespace
        @current_namespace.pop
      end
      
      def current_namespace_name
        @current_namespace.join("::")
      end
      
      def with_namespace(name)
        push_namespace(name)
        yield
      ensure
        pop_namespace
      end
      
      def with_visibility(visibility)
        old_visibility = @current_visibility
        @current_visibility = visibility
        yield
      ensure
        @current_visibility = old_visibility
      end
    end
    
    # Visitor pattern implementation for processing different node types
    class NodeVisitor
      def initialize(context)
        @context = context
        @extractors = {
          Prism::ClassNode => ClassExtractor.new(context),
          Prism::ModuleNode => ModuleExtractor.new(context),
          Prism::DefNode => MethodExtractor.new(context),
          Prism::CallNode => CallExtractor.new(context),
          Prism::ConstantWriteNode => ConstantExtractor.new(context),
          Prism::ConstantPathWriteNode => ConstantExtractor.new(context),
          Prism::ClassVariableWriteNode => ClassVariableExtractor.new(context),
          Prism::AliasMethodNode => AliasExtractor.new(context)
        }
      end
      
      def visit(node)
        return unless node
        
        extractor = @extractors[node.class]
        extractor&.extract(node)
        
        visit_children(node)
      end
      
      private
      
      def visit_children(node)
        return unless node.respond_to?(:child_nodes)
        
        node.child_nodes.compact.each do |child|
          visit(child)
        end
      end
    end

    # Extract symbols from a Ruby file
    def extract_from_file(file_path)
      raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)
      
      code = File.read(file_path)
      result = extract_from_code(code)
      result.file_path = file_path
      result
    rescue => e
      error_result(e, file_path)
    end

    # Extract symbols from Ruby code string
    def extract_from_code(code)
      @context.result = Result.new
      @context.code_lines = code.lines
      parse_result = Prism.parse(code)
      
      if parse_result.success?
        @node_visitor.visit(parse_result.value)
        @context.result
      else
        handle_parse_errors(parse_result)
        @context.result
      end
    rescue => e
      @context.result.errors << { type: "extraction_error", message: e.message }
      @context.result
    end

    private
    
    def handle_parse_errors(parse_result)
      parse_result.errors.each do |error|
        @context.result.errors << {
          type: "parse_error",
          message: error.message,
          location: error.location
        }
      end
    end
    
    def error_result(error, file_path = nil)
      result = Result.new
      result.file_path = file_path
      result.errors << { type: "file_error", message: error.message }
      result
    end
    
    # Base class for all extractors using Strategy pattern
    class BaseExtractor
      def initialize(context)
        @context = context
      end
      
      protected
      
      def extract_constant_name(node)
        return nil unless node

        case node
        when Prism::ConstantReadNode
          node.name.to_s
        when Prism::ConstantPathNode
          if node.parent
            parent_name = extract_constant_name(node.parent)
            "#{parent_name}::#{node.child.name}"
          else
            node.child.name.to_s
          end
        when String
          node
        when Symbol
          node.to_s
        else
          node.to_s
        end
      end
      
      def extract_documentation(node)
        return nil unless node&.location && @context.code_lines
        
        start_line = node.location.start_line - 1  # Convert to 0-based indexing
        
        # Look for comments immediately preceding the node
        doc_lines = []
        (start_line - 1).downto(0) do |line_idx|
          line = @context.code_lines[line_idx]&.strip
          break unless line
          
          if line.start_with?('#')
            # Remove leading # and whitespace
            comment = line.sub(/^#+\s?/, '')
            doc_lines.unshift(comment)
          elsif line.empty?
            # Skip empty lines
            next
          else
            # Stop at first non-comment, non-empty line
            break
          end
        end
        
        return nil if doc_lines.empty?
        doc_lines.join("\n")
      end
    end
    
    # Strategy for extracting class information
    class ClassExtractor < BaseExtractor
      def extract(node)
        name = extract_constant_name(node.constant_path)
        superclass = extract_superclass(node.superclass)
        
        class_info = ClassInfo.new(
          name: build_namespaced_name(name),
          superclass: superclass,
          location: node.location,
          doc: extract_documentation(node)
        )
        
        @context.result.classes << class_info
        
        # Process class body with proper namespace context
        @context.with_namespace(name) do
          @context.with_visibility(:public) do
            if node.body
              NodeVisitor.new(@context).visit(node.body)
            end
          end
        end
      end
      
      private
      
      def extract_superclass(node)
        return nil unless node
        extract_constant_name(node)
      end
      
      def build_namespaced_name(name)
        if @context.current_namespace.empty?
          name
        else
          "#{@context.current_namespace_name}::#{name}"
        end
      end
    end
    
    # Strategy for extracting module information
    class ModuleExtractor < BaseExtractor
      def extract(node)
        name = extract_constant_name(node.constant_path)
        
        module_info = ModuleInfo.new(
          name: build_namespaced_name(name),
          location: node.location,
          doc: extract_documentation(node)
        )
        
        @context.result.modules << module_info
        
        # Check for ActiveSupport::Concern pattern
        detect_concern_pattern(node)
        
        # Process module body with proper namespace context
        @context.with_namespace(name) do
          @context.with_visibility(:public) do
            if node.body
              NodeVisitor.new(@context).visit(node.body)
            end
          end
        end
      end
      
      private
      
      def build_namespaced_name(name)
        if @context.current_namespace.empty?
          name
        else
          "#{@context.current_namespace_name}::#{name}"
        end
      end
      
      def detect_concern_pattern(node)
        # Look for extend ActiveSupport::Concern in module body
        return unless node.body
        
        if has_concern_extend?(node.body)
          @context.result.patterns << PatternInfo.new(
            type: "concern",
            indicators: ["ActiveSupport::Concern"]
          )
        end
      end
      
      def has_concern_extend?(body_node)
        # Look for extend ActiveSupport::Concern pattern
        return false unless body_node.respond_to?(:child_nodes)
        
        body_node.child_nodes.compact.any? do |child|
          if child.is_a?(Prism::CallNode) && child.name == :extend
            child.arguments&.arguments&.any? do |arg|
              extract_constant_name(arg) == "ActiveSupport::Concern"
            end
          else
            false
          end
        end
      end
    end
    
    # Strategy for extracting method information
    class MethodExtractor < BaseExtractor
      def extract(node)
        scope = node.receiver ? "class" : "instance"
        
        # Extract documentation and store it for parameter processing
        doc = extract_documentation(node)
        @current_method_doc = doc
        
        method_info = MethodInfo.new(
          name: node.name.to_s,
          visibility: @context.current_visibility.to_s,
          receiver_type: scope,
          params: extract_parameters(node.parameters),
          location: node.location,
          doc: doc
        )
        
        @context.result.methods << method_info
      ensure
        @current_method_doc = nil
      end
      
      private
      
      def extract_parameters(params_node)
        return [] unless params_node

        params = []
        
        # Handle different parameter types with enhanced information
        if params_node.requireds
          params_node.requireds.each do |param|
            param_obj = OpenStruct.new(
              name: param.name.to_s, 
              type: "required",
              type_hint: extract_type_hint(param)
            )
            params << param_obj
          end
        end
        
        if params_node.optionals
          params_node.optionals.each do |param|
            param_obj = OpenStruct.new(
              name: param.name.to_s, 
              type: "optional",
              default: extract_default_value(param.value),
              type_hint: extract_type_hint(param)
            )
            params << param_obj
          end
        end
        
        if params_node.rest
          param_obj = OpenStruct.new(
            name: params_node.rest.name.to_s, 
            type: "rest",
            type_hint: extract_type_hint(params_node.rest)
          )
          params << param_obj
        end
        
        if params_node.keywords
          params_node.keywords.each do |param|
            param_obj = OpenStruct.new(
              name: param.name.to_s, 
              type: "keyword",
              type_hint: extract_type_hint(param)
            )
            params << param_obj
          end
        end
        
        if params_node.keyword_rest
          param_obj = OpenStruct.new(
            name: params_node.keyword_rest.name.to_s, 
            type: "keyword_rest",
            type_hint: extract_type_hint(params_node.keyword_rest)
          )
          params << param_obj
        end
        
        if params_node.block
          param_obj = OpenStruct.new(
            name: params_node.block.name.to_s, 
            type: "block",
            type_hint: extract_type_hint(params_node.block)
          )
          params << param_obj
        end
        
        params
      end
      
      def extract_type_hint(param)
        # Extract type hints from method documentation
        return nil unless @current_method_doc
        
        # Look for @param name [Type] pattern
        param_name = param.name if param.respond_to?(:name)
        return nil unless param_name
        
        # Simple regex to match @param name [Type] description
        match = @current_method_doc.match(/@param\s+#{Regexp.escape(param_name)}\s+\[([^\]]+)\]/)
        match ? match[1] : nil
      end
      
      def extract_default_value(value_node)
        return nil unless value_node
        
        case value_node
        when Prism::HashNode then "{}"
        when Prism::ArrayNode then "[]"
        when Prism::StringNode then "\"#{value_node.content}\""
        when Prism::IntegerNode then value_node.value.to_s
        else value_node.inspect
        end
      end
    end

    # Strategy for extracting call information (attr_*, include, extend, etc.)
    class CallExtractor < BaseExtractor
      def extract(node)
        return unless node.name

        case node.name
        when :attr_reader, :attr_writer, :attr_accessor
          extract_attributes(node)
        when :include, :extend, :prepend
          extract_mixin(node)
        when :private, :protected, :public
          @context.current_visibility = node.name
        when :require, :require_relative
          extract_dependency(node)
        when :autoload
          extract_autoload(node)
        when :alias_method
          extract_alias_method(node)
        end
      end
      
      private
      
      def extract_attributes(node)
        type = node.name.to_s.sub("attr_", "")
        
        node.arguments&.arguments&.each do |arg|
          if arg.is_a?(Prism::SymbolNode)
            name = arg.value.to_s
            @context.result.attributes << AttributeInfo.new(
              name: name,
              type: type,
              location: arg.location
            )
          end
        end
      end
      
      def extract_mixin(node)
        return unless node.arguments&.arguments&.first

        module_name = extract_constant_name(node.arguments.arguments.first)
        
        mixin_info = MixinInfo.new(
          type: node.name.to_s,
          module_name: module_name,
          target: @context.current_namespace_name,
          location: node.location
        )
        
        @context.result.mixins << mixin_info
      end
      
      def extract_dependency(node)
        return unless node.arguments&.arguments&.first
        
        arg = node.arguments.arguments.first
        if arg.is_a?(Prism::StringNode)
          path_or_name = arg.content
          
          dependency = DependencyInfo.new(
            type: node.name.to_s,
            name: node.name == :require ? path_or_name : nil,
            path: node.name == :require_relative ? path_or_name : nil,
            external: node.name == :require && !path_or_name.start_with?('.') && !path_or_name.include?('/')
          )
          
          @context.result.dependencies << dependency
        end
      end
      
      def extract_autoload(node)
        return unless node.arguments&.arguments&.length == 2
        
        constant_arg = node.arguments.arguments[0]
        path_arg = node.arguments.arguments[1]
        
        if constant_arg.is_a?(Prism::SymbolNode) && path_arg.is_a?(Prism::StringNode)
          dependency = DependencyInfo.new(
            type: "autoload",
            constant: constant_arg.value.to_s,
            path: path_arg.content
          )
          
          @context.result.dependencies << dependency
        end
      end
      
      def extract_alias_method(node)
        return unless node.arguments&.arguments&.length == 2
        
        new_name_arg = node.arguments.arguments[0]
        old_name_arg = node.arguments.arguments[1]
        
        if new_name_arg.is_a?(Prism::SymbolNode) && old_name_arg.is_a?(Prism::SymbolNode)
          alias_info = AliasInfo.new(
            new_name: new_name_arg.value.to_s,
            original_name: old_name_arg.value.to_s
          )
          
          @context.result.aliases << alias_info
        end
      end
    end

    # Strategy for extracting constant information
    class ConstantExtractor < BaseExtractor
      def extract(node)
        name = case node
               when Prism::ConstantWriteNode
                 node.name.to_s
               when Prism::ConstantPathWriteNode
                 extract_constant_name(node.target)
               end

        value = extract_constant_value(node.value) if node.respond_to?(:value)
        
        constant_info = ConstantInfo.new(
          name: name,
          value: value,
          location: node.location
        )
        
        @context.result.constants << constant_info
      end
      
      private
      
      def extract_constant_value(value_node)
        return nil unless value_node
        
        case value_node
        when Prism::StringNode
          "\"#{value_node.content}\""
        when Prism::IntegerNode
          value_node.value.to_s
        when Prism::ArrayNode
          "[...]"
        when Prism::HashNode
          "{...}"
        when Prism::CallNode
          # Handle cases like %w[json yaml xml].freeze
          if value_node.receiver.is_a?(Prism::ArrayNode) && value_node.name == :freeze
            "[...]"
          else
            "[...]"
          end
        else
          "[...]"
        end
      end
    end

    # Strategy for extracting class variable information
    class ClassVariableExtractor < BaseExtractor
      def extract(node)
        name = node.name.to_s
        initial_value = extract_initial_value(node.value) if node.respond_to?(:value)
        
        class_var_info = ClassVariableInfo.new(
          name: name,
          initial_value: initial_value
        )
        
        @context.result.class_variables << class_var_info
      end
      
      private
      
      def extract_initial_value(value_node)
        return nil unless value_node
        
        case value_node
        when Prism::IntegerNode then value_node.value.to_s
        when Prism::StringNode then "\"#{value_node.content}\""
        else value_node.inspect
        end
      end
    end

    # Strategy for extracting alias information
    class AliasExtractor < BaseExtractor
      def extract(node)
        if node.respond_to?(:new_name) && node.respond_to?(:old_name)
          alias_info = AliasInfo.new(
            new_name: extract_method_name(node.new_name),
            original_name: extract_method_name(node.old_name)
          )
          
          @context.result.aliases << alias_info
        end
      end
      
      private
      
      def extract_method_name(name_node)
        case name_node
        when Prism::SymbolNode then name_node.value.to_s
        when Prism::StringNode then name_node.content
        else name_node.to_s
        end
      end
    end
  end
end