# frozen_string_literal: true

require_relative "base_metric"

module Rubymap
  class Enricher
    module Metrics
      # Calculates dependency metrics like fan-in, fan-out, and coupling
      class DependencyMetric < BaseMetric
        def calculate(result, config)
          # Build dependency graph
          dependency_graph = build_dependency_graph(result)

          # Calculate metrics for each class
          result.classes.each do |klass|
            calculate_fan_metrics(klass, dependency_graph)
            calculate_coupling_strength(klass, dependency_graph)
          end

          # Identify coupling hotspots
          identify_coupling_hotspots(result, config)
        end

        private

        def build_dependency_graph(result)
          graph = {
            dependencies: Hash.new { |h, k| h[k] = [] },
            dependents: Hash.new { |h, k| h[k] = [] }
          }

          # Build from explicit dependencies
          result.classes.each do |klass|
            klass.dependencies&.each do |dep|
              graph[:dependencies][klass.name] << dep
              graph[:dependents][dep] << klass.name
            end

            # Add superclass as dependency
            if klass.superclass
              graph[:dependencies][klass.name] << klass.superclass
              graph[:dependents][klass.superclass] << klass.name
            end

            # Add mixins as dependencies
            klass.mixins&.each do |mixin|
              mod_name = mixin[:module] || mixin["module"]
              if mod_name
                graph[:dependencies][klass.name] << mod_name
                graph[:dependents][mod_name] << klass.name
              end
            end
          end

          # Build from method calls
          result.method_calls.each do |call|
            # Handle both hash and object access patterns
            from_value = call.is_a?(Hash) ? call[:from] : call.from
            to_value = call.is_a?(Hash) ? call[:to] : call.to

            from_class = extract_class_name(from_value)
            to_class = extract_class_name(to_value)

            if from_class && to_class && from_class != to_class
              graph[:dependencies][from_class] << to_class
              graph[:dependents][to_class] << from_class
            end
          end

          # Remove duplicates
          graph[:dependencies].each { |k, v| graph[:dependencies][k] = v.uniq }
          graph[:dependents].each { |k, v| graph[:dependents][k] = v.uniq }

          graph
        end

        def calculate_fan_metrics(klass, graph)
          # Fan-out: number of classes this class depends on
          klass.fan_out = graph[:dependencies][klass.name].size

          # Fan-in: number of classes that depend on this class
          klass.fan_in = graph[:dependents][klass.name].size
        end

        def calculate_coupling_strength(klass, graph)
          # Simple coupling strength based on fan-in and fan-out
          total_connections = klass.fan_in.to_i + klass.fan_out.to_i

          # Normalize to 0-10 scale
          klass.coupling_strength = if total_connections == 0
            0.0
          elsif total_connections <= 2
            1.0
          elsif total_connections <= 5
            3.0
          elsif total_connections <= 10
            5.0
          elsif total_connections <= 20
            7.0
          else
            9.0
          end
        end

        def extract_class_name(method_reference)
          return nil unless method_reference

          # Extract class name from references like "User#save" or "User.find"
          if method_reference =~ /^([A-Z][A-Za-z0-9_:]*)[#.]/
            $1
          end
        end

        def identify_coupling_hotspots(result, config)
          result.coupling_hotspots ||= []

          # Identify classes with high fan-out (too many dependencies)
          fan_out_threshold = config_value(config, :fan_out_threshold, 5)

          result.classes.each do |klass|
            if klass.fan_out && klass.fan_out >= fan_out_threshold
              result.coupling_hotspots << CouplingHotspot.new(
                class: klass.name,
                reason: "high_fan_out",
                fan_out: klass.fan_out
              )
            end

            # Also check for high coupling strength
            if klass.coupling_strength && klass.coupling_strength >= 7.0
              result.coupling_hotspots << CouplingHotspot.new(
                class: klass.name,
                reason: "high_coupling_strength",
                fan_out: klass.fan_out
              )
            end
          end
        end
      end
    end
  end
end
