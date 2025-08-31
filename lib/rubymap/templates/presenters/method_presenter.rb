# frozen_string_literal: true

module Rubymap
  module Templates
    module Presenters
      # Presenter for method data
      class MethodPresenter < BasePresenter
        def name
          get(:name) || "unknown"
        end

        def visibility
          get(:visibility) || "public"
        end

        def is_public?
          visibility == "public"
        end

        def is_private?
          visibility == "private"
        end

        def is_protected?
          visibility == "protected"
        end

        def scope
          get(:scope) || get(:receiver_type) || "instance"
        end

        def is_instance_method?
          scope == "instance"
        end

        def is_class_method?
          scope == "class"
        end

        def prefix
          is_class_method? ? "." : "#"
        end

        def signature
          "#{prefix}#{name}#{formatted_parameters}"
        end

        def parameters
          @parameters ||= (get(:parameters) || get(:params) || []).map do |param|
            ParameterPresenter.new(param.is_a?(Hash) ? param : {name: param})
          end
        end

        def has_parameters?
          !parameters.empty?
        end

        def formatted_parameters
          return "()" unless has_parameters?
          "(#{parameters.map(&:to_s).join(", ")})"
        end

        def has_documentation?
          has?(:documentation)
        end

        def documentation
          get(:documentation)
        end

        def complexity
          get(:complexity) || 1
        end

        def is_complex?
          complexity > 5
        end

        def lines
          get(:lines) || 0
        end

        def is_long?
          lines > 10
        end

        def location
          @location ||= LocationPresenter.new(get(:location) || {})
        end

        def has_location?
          location.valid?
        end
      end

      # Presenter for parameter data
      class ParameterPresenter < BasePresenter
        def name
          get(:name) || "param"
        end

        def type
          get(:type) || "required"
        end

        def default_value
          get(:default)
        end

        def has_default?
          !default_value.nil?
        end

        def to_s
          case type
          when "required"
            name
          when "optional"
            "#{name} = #{default_value}"
          when "rest"
            "*#{name}"
          when "keyword"
            "#{name}:"
          when "keyword_optional"
            "#{name}: #{default_value}"
          when "keyword_rest"
            "**#{name}"
          when "block"
            "&#{name}"
          else
            name
          end
        end
      end
    end
  end
end
