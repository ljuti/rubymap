# frozen_string_literal: true

module Rubymap
  module Templates
    module Presenters
      # Base presenter for wrapping data objects
      class BasePresenter
        attr_reader :data

        def initialize(data)
          @data = data || {}
        end

        # Allow direct access to data fields
        def method_missing(method_name, *args, &block)
          if @data.respond_to?(method_name)
            @data.send(method_name, *args, &block)
          elsif @data.is_a?(Hash)
            # Try symbol key first, then string key
            @data[method_name] || @data[method_name.to_s]
          else
            super
          end
        end

        def respond_to_missing?(method_name, include_private = false)
          @data.respond_to?(method_name) ||
            (@data.is_a?(Hash) && (@data.key?(method_name) || @data.key?(method_name.to_s))) ||
            super
        end

        # Check if a field is present
        def has?(field)
          value = @data[field] || @data[field.to_s]
          !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
        end

        # Get field value with fallback
        def get(field, default = nil)
          @data[field] || @data[field.to_s] || default
        end

        # Convert to hash
        def to_h
          @data.respond_to?(:to_h) ? @data.to_h : @data
        end
      end
    end
  end
end
