# frozen_string_literal: true

module Rubymap
  module Templates
    module Presenters
      # Presenter for class data
      class ClassPresenter < BasePresenter
        def full_name
          get(:fqname) || get(:name) || "Unknown"
        end

        def simple_name
          full_name.to_s.split("::").last
        end

        def namespace
          parts = full_name.to_s.split("::")
          (parts.size > 1) ? parts[0..-2].join("::") : nil
        end

        def has_superclass?
          has?(:superclass) && get(:superclass) != "Object"
        end

        def superclass_name
          get(:superclass) || "Object"
        end

        def has_documentation?
          has?(:documentation)
        end

        def documentation
          get(:documentation)
        end

        def has_metrics?
          has?(:metrics)
        end

        def metrics
          @metrics ||= MetricsPresenter.new(get(:metrics) || {})
        end

        def complexity_score
          metrics.complexity_score
        end

        def complexity_label
          metrics.complexity_label
        end

        def location
          @location ||= LocationPresenter.new(get(:location) || {})
        end

        def has_location?
          location.valid?
        end

        def formatted_location
          location.to_s
        end

        def instance_methods
          @instance_methods ||= (get(:instance_methods) || []).map do |method|
            MethodPresenter.new(method.is_a?(Hash) ? method : {name: method})
          end
        end

        def class_methods
          @class_methods ||= (get(:class_methods) || []).map do |method|
            MethodPresenter.new(method.is_a?(Hash) ? method : {name: method})
          end
        end

        def has_instance_methods?
          !instance_methods.empty?
        end

        def has_class_methods?
          !class_methods.empty?
        end

        def total_methods
          instance_methods.size + class_methods.size
        end

        def has_mixins?
          mixins = get(:mixins) || []
          !mixins.empty?
        end

        def mixins
          @mixins ||= (get(:mixins) || []).map do |mixin|
            MixinPresenter.new(mixin)
          end
        end

        def included_modules
          mixins.select { |m| m.type == "include" }
        end

        def extended_modules
          mixins.select { |m| m.type == "extend" }
        end

        def prepended_modules
          mixins.select { |m| m.type == "prepend" }
        end

        # Helper for templates
        def type_label
          get(:type) || "class"
        end

        def is_rails_model?
          superclass_name&.include?("ActiveRecord") || superclass_name&.include?("ApplicationRecord")
        end

        def is_rails_controller?
          full_name.to_s.include?("Controller") || superclass_name&.include?("Controller")
        end

        def is_rails_concern?
          included_modules.any? { |m| m.name.include?("ActiveSupport::Concern") }
        end
      end

      # Presenter for metrics data
      class MetricsPresenter < BasePresenter
        def complexity_score
          get(:complexity_score) || get(:complexity) || 0
        end

        def complexity_label
          score = complexity_score
          if score > 7
            "high"
          elsif score > 4
            "medium"
          else
            "low"
          end
        end

        def public_api_surface
          get(:public_api_surface) || 0
        end

        def test_coverage
          get(:test_coverage)
        end

        def has_test_coverage?
          !test_coverage.nil?
        end
      end

      # Presenter for location data
      class LocationPresenter < BasePresenter
        def file
          get(:file)
        end

        def line
          get(:line)
        end

        def valid?
          !file.nil? && !line.nil?
        end

        def to_s
          valid? ? "#{file}:#{line}" : ""
        end
      end

      # Presenter for mixin data
      class MixinPresenter < BasePresenter
        def name
          get(:module) || get(:name)
        end

        def type
          get(:type) || "include"
        end

        def is_include?
          type == "include"
        end

        def is_extend?
          type == "extend"
        end

        def is_prepend?
          type == "prepend"
        end
      end
    end
  end
end
