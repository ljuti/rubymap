# frozen_string_literal: true

module Rubymap
  class Enricher
    module Detectors
      # Detects if a project is a Rails application.
      # Separates Rails detection logic for better testability.
      class RailsDetector
        # Rails base classes that indicate a Rails project
        RAILS_BASE_CLASSES = [
          "ApplicationRecord",
          "ApplicationController",
          "ApplicationJob",
          "ApplicationMailer",
          "ApplicationCable::Channel",
          "ApplicationCable::Connection",
          "ActiveRecord::Base",
          "ActionController::Base",
          "ActionController::API"
        ].freeze

        # Detects if the result represents a Rails project.
        #
        # @param result [EnrichmentResult] The result to check
        # @return [Boolean] true if Rails project detected
        def self.rails_project?(result)
          return false unless result.classes.any?

          result.classes.any? do |klass|
            rails_class?(klass)
          end
        end

        # Checks if a class is a Rails class based on its superclass.
        #
        # @param klass [Object] The class to check
        # @return [Boolean] true if class inherits from Rails base class
        def self.rails_class?(klass)
          return false unless klass.superclass

          RAILS_BASE_CLASSES.any? do |base_class|
            klass.superclass.include?(base_class)
          end
        end

        # Detects the type of Rails class (model, controller, etc.).
        #
        # @param klass [Object] The class to categorize
        # @return [Symbol, nil] The Rails class type or nil
        def self.rails_class_type(klass)
          return nil unless klass.superclass

          case klass.superclass
          when /ApplicationRecord|ActiveRecord::Base/
            :model
          when /ApplicationController|ActionController::Base|ActionController::API/
            :controller
          when /ApplicationJob/
            :job
          when /ApplicationMailer/
            :mailer
          when /ApplicationCable::Channel/
            :channel
          when /ApplicationCable::Connection/
            :connection
          end
        end

        # Analyzes Rails-specific characteristics of the project.
        #
        # @param result [EnrichmentResult] The result to analyze
        # @return [Hash] Rails project analysis
        def self.analyze_rails_project(result)
          return {} unless rails_project?(result)

          {
            is_rails: true,
            models: count_by_type(result, :model),
            controllers: count_by_type(result, :controller),
            jobs: count_by_type(result, :job),
            mailers: count_by_type(result, :mailer),
            channels: count_by_type(result, :channel)
          }
        end

        def self.count_by_type(result, type)
          result.classes.count { |klass| rails_class_type(klass) == type }
        end
        private_class_method :count_by_type
      end
    end
  end
end
