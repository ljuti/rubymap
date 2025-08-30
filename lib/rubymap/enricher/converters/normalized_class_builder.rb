# frozen_string_literal: true

module Rubymap
  class Enricher
    module Converters
      # Builder pattern implementation for constructing NormalizedClass objects.
      #
      # This builder handles the complex construction of NormalizedClass structs
      # with their many fields, providing a fluent interface for incremental
      # construction and clear separation of concerns for different field groups.
      class NormalizedClassBuilder
        def initialize
          @attributes = {}
        end

        # Core identification fields
        def symbol_id(value)
          @attributes[:symbol_id] = value
          self
        end

        def name(value)
          @attributes[:name] = value
          self
        end

        def fqname(value)
          @attributes[:fqname] = value
          self
        end

        def kind(value)
          @attributes[:kind] = value
          self
        end

        # Inheritance and structure
        def superclass(value)
          @attributes[:superclass] = value
          self
        end

        def location(value)
          @attributes[:location] = value
          self
        end

        def namespace_path(value)
          @attributes[:namespace_path] = value
          self
        end

        def children(value)
          @attributes[:children] = value
          self
        end

        def inheritance_chain(value)
          @attributes[:inheritance_chain] = value
          self
        end

        # Method collections
        def instance_methods(value)
          @attributes[:instance_methods] = value
          self
        end

        def class_methods(value)
          @attributes[:class_methods] = value
          self
        end

        def available_instance_methods(value)
          @attributes[:available_instance_methods] = value
          self
        end

        def available_class_methods(value)
          @attributes[:available_class_methods] = value
          self
        end

        def method_names(value)
          @attributes[:method_names] = value
          self
        end

        # Mixins and composition
        def mixins(value)
          @attributes[:mixins] = value
          self
        end

        def implements(value)
          @attributes[:implements] = value
          self
        end

        # Metadata and analysis
        def provenance(value)
          @attributes[:provenance] = value
          self
        end

        def dependencies(value)
          @attributes[:dependencies] = value
          self
        end

        def visibility(value)
          @attributes[:visibility] = value
          self
        end

        def file(value)
          @attributes[:file] = value
          self
        end

        # Version control and metrics
        def git_commits(value)
          @attributes[:git_commits] = value
          self
        end

        def last_modified(value)
          @attributes[:last_modified] = value
          self
        end

        def age_in_days(value)
          @attributes[:age_in_days] = value
          self
        end

        def churn_score(value)
          @attributes[:churn_score] = value
          self
        end

        # Quality metrics
        def test_coverage(value)
          @attributes[:test_coverage] = value
          self
        end

        def documentation_coverage(value)
          @attributes[:documentation_coverage] = value
          self
        end

        # Rails-specific fields
        def associations(value)
          @attributes[:associations] = value
          self
        end

        def validations(value)
          @attributes[:validations] = value
          self
        end

        def scopes(value)
          @attributes[:scopes] = value
          self
        end

        def actions(value)
          @attributes[:actions] = value
          self
        end

        def filters(value)
          @attributes[:filters] = value
          self
        end

        def rescue_handlers(value)
          @attributes[:rescue_handlers] = value
          self
        end

        # Batch assignment from hash
        def from_hash(hash)
          hash.each do |key, value|
            case key.to_sym
            when :symbol_id then symbol_id(value)
            when :name then name(value)
            when :fqname then fqname(value)
            when :kind then kind(value)
            when :superclass then superclass(value)
            when :location then location(value)
            when :namespace_path then namespace_path(value)
            when :children then children(value)
            when :inheritance_chain then inheritance_chain(value)
            when :instance_methods then instance_methods(value)
            when :class_methods then class_methods(value)
            when :available_instance_methods then available_instance_methods(value)
            when :available_class_methods then available_class_methods(value)
            when :mixins then mixins(value)
            when :provenance then provenance(value)
            when :dependencies then dependencies(value)
            when :visibility then visibility(value)
            when :git_commits then git_commits(value)
            when :last_modified then last_modified(value)
            when :age_in_days then age_in_days(value)
            when :test_coverage then test_coverage(value)
            when :documentation_coverage then documentation_coverage(value)
            when :churn_score then churn_score(value)
            when :file then file(value)
            when :implements then implements(value)
            when :associations then associations(value)
            when :validations then validations(value)
            when :scopes then scopes(value)
            when :actions then actions(value)
            when :filters then filters(value)
            when :rescue_handlers then rescue_handlers(value)
            when :methods then method_names(value) # Support legacy test data
            end
          end
          self
        end

        # Constructs the final NormalizedClass object
        def build
          Normalizer::NormalizedClass.new(**@attributes)
        end

        # Factory method for one-step construction from hash
        def self.from_hash(hash)
          new.from_hash(hash).build
        end
      end
    end
  end
end