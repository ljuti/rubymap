# frozen_string_literal: true

module Rubymap
  module Templates
    module Presenters
      # Presenter for module data
      class ModulePresenter < BasePresenter
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

        def has_documentation?
          has?(:documentation)
        end

        def documentation
          get(:documentation)
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

        def methods
          @methods ||= (get(:methods) || []).map do |method|
            MethodPresenter.new(method.is_a?(Hash) ? method : {name: method})
          end
        end

        def has_methods?
          !methods.empty?
        end

        def included_in
          get(:included_in) || []
        end

        def extended_in
          get(:extended_in) || []
        end

        def prepended_in
          get(:prepended_in) || []
        end

        def is_included_anywhere?
          !included_in.empty?
        end

        def is_extended_anywhere?
          !extended_in.empty?
        end

        def is_prepended_anywhere?
          !prepended_in.empty?
        end

        def is_used?
          is_included_anywhere? || is_extended_anywhere? || is_prepended_anywhere?
        end

        def usage_count
          included_in.size + extended_in.size + prepended_in.size
        end

        def is_concern?
          get(:is_concern) || full_name.to_s.include?("Concern")
        end

        def type_label
          is_concern? ? "concern" : "module"
        end
      end
    end
  end
end
