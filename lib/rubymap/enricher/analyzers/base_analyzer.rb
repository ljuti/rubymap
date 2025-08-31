# frozen_string_literal: true

module Rubymap
  class Enricher
    module Analyzers
      # Abstract base class for all analyzers and detectors
      class BaseAnalyzer
        # Analyze the enriched result and detect patterns/issues
        def analyze(result, config)
          raise NotImplementedError, "Subclasses must implement #analyze"
        end

        protected

        # Helper to check if a pattern matches based on evidence
        def pattern_matches?(evidence, required_evidence, confidence_threshold = 0.7)
          matched = evidence.count { |key| required_evidence.include?(key) }
          confidence = matched.to_f / required_evidence.size
          confidence >= confidence_threshold
        end

        # Helper to calculate confidence score for a pattern
        def calculate_confidence(evidence, required_evidence, optional_evidence = [])
          required_score = evidence.count { |e| required_evidence.include?(e) }.to_f / required_evidence.size
          optional_score = optional_evidence.empty? ? 0 : evidence.count { |e| optional_evidence.include?(e) }.to_f / optional_evidence.size

          (required_score * 0.7 + optional_score * 0.3).round(2)
        end

        # Helper to detect naming patterns
        def matches_naming_pattern?(name, pattern)
          case pattern
          when Regexp
            name =~ pattern
          when String
            name.downcase.include?(pattern.downcase)
          else
            false
          end
        end

        # Helper to extract evidence from a class or method
        def extract_evidence(symbol)
          evidence = []

          # Check method names
          if symbol.respond_to?(:instance_methods)
            evidence.concat(symbol.instance_methods || [])
          end

          if symbol.respond_to?(:class_methods)
            evidence.concat(symbol.class_methods || [])
          end

          # Check naming patterns
          evidence << "factory_name" if /Factory\z/.match?(symbol.name)
          evidence << "singleton_name" if /Singleton\z/.match?(symbol.name)
          evidence << "observer_name" if /Observer\z/.match?(symbol.name)
          evidence << "strategy_name" if /Strategy\z/.match?(symbol.name)

          evidence
        end
      end
    end
  end
end
