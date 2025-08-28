# frozen_string_literal: true

require_relative "../base_enricher"

module Rubymap
  class Enricher
    module Rails
      # Enriches ActiveRecord models with Rails-specific information
      class ModelEnricher < BaseEnricher
        ACTIVERECORD_INDICATORS = %w[
          ApplicationRecord
          ActiveRecord::Base
        ].freeze

        ASSOCIATION_METHODS = %w[
          has_many
          has_one
          belongs_to
          has_and_belongs_to_many
          has_many_through
        ].freeze

        VALIDATION_METHODS = %w[
          validates
          validates_presence_of
          validates_uniqueness_of
          validates_length_of
          validates_format_of
          validates_inclusion_of
          validates_exclusion_of
          validates_numericality_of
          validate
        ].freeze

        CALLBACK_METHODS = %w[
          before_validation
          after_validation
          before_save
          after_save
          before_create
          after_create
          before_update
          after_update
          before_destroy
          after_destroy
          around_save
          around_create
          around_update
          around_destroy
        ].freeze

        SCOPE_METHODS = %w[
          scope
          default_scope
        ].freeze

        def enrich(result, config)
          result.rails_models ||= []

          result.classes.each do |klass|
            if is_activerecord_model?(klass)
              enrich_model(klass, result)
            end
          end
        end

        private

        def is_activerecord_model?(klass)
          return false unless klass.superclass

          # Check if it inherits from ActiveRecord
          ACTIVERECORD_INDICATORS.any? do |indicator|
            klass.superclass == indicator ||
              klass.superclass&.include?(indicator) ||
              klass.inheritance_chain&.include?(indicator)
          end
        end

        def enrich_model(klass, result)
          # Extract data from test format if available
          associations = klass.associations || extract_associations(klass)
          validations = klass.validations || extract_validations(klass)
          scopes = klass.scopes || extract_scopes(klass)

          model_info = RailsModelInfo.new(
            name: klass.name,
            table_name: infer_table_name(klass),
            associations: associations,
            validations: validations,
            callbacks: extract_callbacks(klass),
            scopes: scopes,
            attributes: extract_attributes(klass),
            database_indexes: extract_indexes(klass),
            concerns: extract_concerns(klass),
            model_type: determine_model_type(klass)
          )

          # Add Rails-specific metrics
          model_info.association_count = associations.size
          model_info.validation_count = validations.size
          model_info.callback_count = model_info.callbacks.size
          model_info.scope_count = scopes.size

          # Calculate model complexity
          model_info.complexity_score = calculate_model_complexity(model_info)

          # Detect potential issues
          model_info.issues = detect_model_issues(model_info)

          # Add to results
          result.rails_models << model_info

          # Enhance the original class with Rails metadata
          klass.is_rails_model = true
          klass.rails_model_info = model_info

          # Add activerecord_metrics for compatibility with tests
          klass.activerecord_metrics = Struct.new(:associations_count, :validations_count, :scopes_count, keyword_init: true).new(
            associations_count: associations.size,
            validations_count: validations.size,
            scopes_count: scopes.is_a?(Array) ? scopes.size : scopes.to_a.size
          )

          # Add model complexity score
          klass.model_complexity_score = model_info.complexity_score
        end

        def infer_table_name(klass)
          # Basic Rails convention: pluralize and underscore
          name = klass.name.split("::").last
          name.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase + "s"
        end

        def extract_associations(klass)
          associations = []

          klass.methods&.each do |method|
            if ASSOCIATION_METHODS.include?(method.name)
              method.calls_made&.each do |call|
                association = {
                  type: method.name,
                  name: call[:arguments]&.first,
                  options: parse_association_options(call[:arguments])
                }

                # Determine association class
                association[:class_name] = infer_association_class(association[:name], association[:type])

                associations << association
              end
            end
          end

          associations
        end

        def extract_validations(klass)
          validations = []

          klass.methods&.each do |method|
            if VALIDATION_METHODS.include?(method.name)
              method.calls_made&.each do |call|
                validation = {
                  type: method.name,
                  attributes: extract_validated_attributes(call[:arguments]),
                  options: parse_validation_options(call[:arguments])
                }

                validations << validation
              end
            end
          end

          validations
        end

        def extract_callbacks(klass)
          callbacks = []

          klass.methods&.each do |method|
            if CALLBACK_METHODS.include?(method.name)
              method.calls_made&.each do |call|
                callback = {
                  type: method.name,
                  method: call[:arguments]&.first,
                  conditions: parse_callback_conditions(call[:arguments])
                }

                callbacks << callback
              end
            end
          end

          callbacks
        end

        def extract_scopes(klass)
          scopes = []

          klass.methods&.each do |method|
            if SCOPE_METHODS.include?(method.name)
              method.calls_made&.each do |call|
                scope = {
                  name: call[:arguments]&.first,
                  type: method.name,
                  lambda: call[:arguments]&.[](1)&.start_with?("->")
                }

                scopes << scope
              end
            end
          end

          scopes
        end

        def extract_attributes(klass)
          attributes = []

          # Look for attr_accessor, attr_reader, attr_writer
          %w[attr_accessor attr_reader attr_writer].each do |attr_method|
            method = klass.methods&.find { |m| m.name == attr_method }
            method&.calls_made&.each do |call|
              call[:arguments]&.each do |arg|
                attributes << {
                  name: arg,
                  type: "virtual",
                  accessor: attr_method
                }
              end
            end
          end

          # Look for database columns (usually in schema or migrations)
          # This would need integration with schema analysis

          attributes
        end

        def extract_indexes(klass)
          # This would need integration with schema/migration analysis
          []
        end

        def extract_concerns(klass)
          concerns = []

          # Look for include statements with Concerns
          klass.mixins&.each do |mixin|
            module_name = mixin[:module] || mixin["module"]
            if module_name&.include?("Concern") || module_name&.include?("able")
              concerns << module_name
            end
          end

          concerns
        end

        def determine_model_type(klass)
          name = klass.name.downcase

          if name.include?("join") || name.include?("through")
            "join_table"
          elsif klass.methods&.any? { |m| m.name == "has_secure_password" }
            "user_model"
          elsif name.include?("setting") || name.include?("config")
            "configuration"
          elsif klass.methods&.any? { |m| m.name == "acts_as_tree" || m.name == "has_ancestry" }
            "hierarchical"
          elsif klass.methods&.any? { |m| m.name == "acts_as_taggable" }
            "taggable"
          else
            "standard"
          end
        end

        def calculate_model_complexity(model_info)
          score = 0.0

          # Base complexity from counts
          score += model_info.association_count * 2
          score += model_info.validation_count * 1
          score += model_info.callback_count * 3  # Callbacks add more complexity
          score += model_info.scope_count * 1

          # Additional complexity factors
          score += 5 if model_info.callbacks.any? { |c| c.is_a?(Hash) && c[:type]&.start_with?("around_") }
          score += 3 if model_info.associations.any? { |a| a[:type] == "has_many_through" }
          score += 2 if model_info.scopes.any? do |s|
            s.is_a?(Hash) ? s[:type] == "default_scope" : s == "default_scope"
          end

          # Normalize to 0-100
          [score, 100].min
        end

        def detect_model_issues(model_info)
          issues = []

          # Check for N+1 query risks
          if model_info.associations.size > 5
            issues << {
              type: "n_plus_one_risk",
              severity: "high",
              message: "Model has many associations, consider using includes() to avoid N+1 queries"
            }
          end

          # Check for too many callbacks
          if model_info.callback_count > 10
            issues << {
              type: "callback_hell",
              severity: "high",
              message: "Too many callbacks can make the model hard to understand and debug"
            }
          end

          # Check for default_scope usage
          if model_info.scopes.any? { |s| s.is_a?(Hash) ? s[:type] == "default_scope" : s == "default_scope" }
            issues << {
              type: "default_scope_usage",
              severity: "medium",
              message: "default_scope can lead to unexpected behavior, consider using named scopes"
            }
          end

          # Check for missing validations
          if model_info.validation_count == 0
            issues << {
              type: "missing_validations",
              severity: "medium",
              message: "Model has no validations, consider adding data integrity checks"
            }
          end

          # Check for missing indexes on foreign keys
          foreign_keys = model_info.associations
            .select { |a| a[:type] == "belongs_to" }
            .map { |a| "#{a[:name]}_id" }

          if foreign_keys.any? && model_info.database_indexes.empty?
            issues << {
              type: "missing_indexes",
              severity: "high",
              message: "Foreign key columns may be missing indexes, affecting query performance"
            }
          end

          issues
        end

        def parse_association_options(arguments)
          return {} unless arguments&.size&.> 1

          # Extract hash options from arguments
          options = {}
          arguments[1..].each do |arg|
            if arg.is_a?(Hash)
              options.merge!(arg)
            elsif arg.include?(":")
              # Parse string representation of hash
              key, value = arg.split(":", 2).map(&:strip)
              options[key.to_sym] = value
            end
          end

          options
        end

        def parse_validation_options(arguments)
          parse_association_options(arguments)
        end

        def parse_callback_conditions(arguments)
          return {} unless arguments&.size&.> 1

          conditions = {}
          arguments[1..].each do |arg|
            if arg.include?("if:")
              conditions[:if] = arg.split("if:").last.strip
            elsif arg.include?("unless:")
              conditions[:unless] = arg.split("unless:").last.strip
            end
          end

          conditions
        end

        def extract_validated_attributes(arguments)
          return [] unless arguments

          # First arguments before options hash are attribute names
          attributes = []
          arguments.each do |arg|
            break if arg.is_a?(Hash) || arg.include?(":")
            attributes << arg
          end

          attributes
        end

        def infer_association_class(name, type)
          return nil unless name

          case type
          when "belongs_to", "has_one"
            # Singularize and camelize
            name.to_s.camelize
          when "has_many", "has_and_belongs_to_many"
            # Singularize and camelize
            name.to_s.singularize.camelize
          else
            name.to_s.camelize
          end
        end
      end
    end
  end
end
