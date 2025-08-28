# frozen_string_literal: true

require_relative "base_analyzer"

module Rubymap
  class Enricher
    module Analyzers
      # Detects Ruby idioms and protocols
      class IdiomDetector < BaseAnalyzer
        RUBY_PROTOCOLS = {
          "String conversion protocol" => %w[to_s to_str],
          "Integer conversion protocol" => %w[to_i to_int],
          "Array conversion protocol" => %w[to_a to_ary],
          "Hash conversion protocol" => %w[to_h to_hash],
          "Enumerable protocol" => %w[each],
          "Comparable protocol" => %w[<=>],
          "Hash-like access protocol" => %w[[] []=],
          "Range protocol" => %w[begin end exclude_end?],
          "IO protocol" => %w[read write close],
          "Coercion protocol" => %w[coerce]
        }.freeze
        
        def analyze(result, config)
          result.ruby_idioms ||= []
          
          # Detect idioms in methods
          result.methods.each do |method|
            detect_method_idioms(method, result)
          end
          
          # Detect class-level idioms
          result.classes.each do |klass|
            detect_class_idioms(klass, result)
          end
        end
        
        private
        
        def detect_method_idioms(method, result)
          # Check for protocol implementations
          RUBY_PROTOCOLS.each do |protocol_name, protocol_methods|
            if protocol_methods.include?(method.name)
              method.implements_protocol = protocol_name
              
              result.ruby_idioms << RubyIdiom.new(
                idiom: protocol_name,
                class: method.owner,
                method: method.name
              )
            end
          end
          
          # Check for yielding methods (Enumerable-like)
          if method.yields
            result.ruby_idioms << RubyIdiom.new(
              idiom: "Enumerable protocol",
              class: method.owner,
              method: method.name
            )
          end
          
          # Check for DSL methods (methods that take blocks)
          if method.name =~ /^(define|create|build|configure|setup)_/
            result.ruby_idioms << RubyIdiom.new(
              idiom: "DSL pattern",
              class: method.owner,
              method: method.name
            )
          end
          
          # Check for predicate methods
          if method.name.end_with?("?")
            result.ruby_idioms << RubyIdiom.new(
              idiom: "Predicate method",
              class: method.owner,
              method: method.name
            )
          end
          
          # Check for bang methods
          if method.name.end_with?("!")
            result.ruby_idioms << RubyIdiom.new(
              idiom: "Bang method",
              class: method.owner,
              method: method.name
            )
          end
        end
        
        def detect_class_idioms(klass, result)
          methods = klass.instance_methods || []
          
          # Check if class implements full protocols
          RUBY_PROTOCOLS.each do |protocol_name, protocol_methods|
            if protocol_methods.all? { |m| methods.include?(m) }
              result.ruby_idioms << RubyIdiom.new(
                idiom: "Complete #{protocol_name}",
                class: klass.name,
                method: nil
              )
            end
          end
          
          # Check for attr_accessor pattern (has both getter and setter)
          methods.each do |method|
            if !method.end_with?("=") && methods.include?("#{method}=")
              result.ruby_idioms << RubyIdiom.new(
                idiom: "Attribute accessor pattern",
                class: klass.name,
                method: method
              )
            end
          end
          
          # Check for module mixins that indicate protocol compliance
          if klass.mixins
            klass.mixins.each do |mixin|
              module_name = mixin[:module] || mixin["module"]
              
              case module_name
              when /Enumerable/
                result.ruby_idioms << RubyIdiom.new(
                  idiom: "Enumerable inclusion",
                  class: klass.name,
                  method: nil
                )
              when /Comparable/
                result.ruby_idioms << RubyIdiom.new(
                  idiom: "Comparable inclusion",
                  class: klass.name,
                  method: nil
                )
              when /Singleton/
                result.ruby_idioms << RubyIdiom.new(
                  idiom: "Singleton pattern",
                  class: klass.name,
                  method: nil
                )
              end
            end
          end
        end
      end
    end
  end
end