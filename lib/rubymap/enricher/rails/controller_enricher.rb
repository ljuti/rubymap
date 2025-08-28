# frozen_string_literal: true

require_relative "../base_enricher"

module Rubymap
  class Enricher
    module Rails
      # Enriches Rails controllers with Rails-specific information
      class ControllerEnricher < BaseEnricher
        CONTROLLER_INDICATORS = %w[
          ApplicationController
          ActionController::Base
          ActionController::API
        ].freeze

        FILTER_METHODS = %w[
          before_action
          after_action
          around_action
          skip_before_action
          skip_after_action
          skip_around_action
          before_filter
          after_filter
          around_filter
        ].freeze

        REST_ACTIONS = %w[
          index
          show
          new
          create
          edit
          update
          destroy
        ].freeze

        RESPONSE_METHODS = %w[
          render
          redirect_to
          respond_to
          respond_with
          head
        ].freeze

        AUTHENTICATION_METHODS = %w[
          authenticate_user!
          require_login
          authorize
          authorize!
          authenticate
        ].freeze

        def enrich(result, config)
          result.rails_controllers ||= []

          result.classes.each do |klass|
            if is_rails_controller?(klass)
              enrich_controller(klass, result)
            end
          end
        end

        private

        def is_rails_controller?(klass)
          return false unless klass.superclass || klass.name&.end_with?("Controller")

          # Check if it inherits from a controller base class
          CONTROLLER_INDICATORS.any? do |indicator|
            klass.superclass == indicator ||
              klass.superclass&.include?(indicator) ||
              klass.inheritance_chain&.include?(indicator)
          end || klass.name&.end_with?("Controller")
        end

        def enrich_controller(klass, result)
          # Use test data if available
          actions = klass.actions || extract_actions(klass)
          filters = klass.filters || extract_filters(klass)
          rescue_handlers = klass.rescue_handlers || extract_rescue_handlers(klass)

          controller_info = RailsControllerInfo.new(
            name: klass.name,
            resource_name: infer_resource_name(klass),
            actions: actions,
            filters: filters,
            strong_parameters: extract_strong_parameters(klass),
            rescue_handlers: rescue_handlers,
            concerns: extract_controller_concerns(klass),
            api_controller: is_api_controller?(klass),
            authentication: extract_authentication_info(klass),
            routes: infer_routes(klass)
          )

          # Add metrics
          controller_info.action_count = actions.is_a?(Array) ? actions.size : actions.to_a.size
          controller_info.filter_count = filters.is_a?(Array) ? filters.size : filters.to_a.size
          controller_info.rest_compliance = calculate_rest_compliance(controller_info)
          controller_info.complexity_score = calculate_controller_complexity(controller_info)

          # Detect issues
          controller_info.issues = detect_controller_issues(controller_info, klass)

          # Add to results
          result.rails_controllers << controller_info

          # Enhance original class
          klass.is_rails_controller = true
          klass.rails_controller_info = controller_info

          # Add controller_metrics for compatibility with tests
          klass.controller_metrics = Struct.new(:actions_count, :filters_count, :rescue_handlers_count, keyword_init: true).new(
            actions_count: controller_info.action_count,
            filters_count: controller_info.filter_count,
            rescue_handlers_count: rescue_handlers.is_a?(Array) ? rescue_handlers.size : rescue_handlers.to_a.size
          )
        end

        def infer_resource_name(klass)
          # Remove Controller suffix and underscore
          klass.name
            .gsub(/Controller$/, "")
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
        end

        def extract_actions(klass)
          actions = []

          klass.methods&.each do |method|
            # Public instance methods that aren't filters or helpers
            if method.visibility == "public" &&
                !FILTER_METHODS.include?(method.name) &&
                !method.name.start_with?("_")

              action = {
                name: method.name,
                type: categorize_action(method.name),
                http_verb: infer_http_verb(method.name),
                responds_with: extract_response_format(method),
                requires_auth: requires_authentication?(method),
                complexity: method.complexity || 1
              }

              actions << action
            end
          end

          actions
        end

        def extract_filters(klass)
          filters = []

          klass.methods&.each do |method|
            if FILTER_METHODS.include?(method.name)
              method.calls_made&.each do |call|
                filter = {
                  type: method.name,
                  method: call[:arguments]&.first,
                  only: extract_filter_option(call[:arguments], :only),
                  except: extract_filter_option(call[:arguments], :except),
                  conditions: extract_filter_conditions(call[:arguments])
                }

                filters << filter
              end
            end
          end

          filters
        end

        def extract_strong_parameters(klass)
          params = []

          klass.methods&.each do |method|
            if method.name.end_with?("_params") || method.name == "permitted_params"
              # Analyze method for permit/require calls
              permit_calls = method.calls_made&.select { |c| c[:method] == "permit" }
              require_calls = method.calls_made&.select { |c| c[:method] == "require" }

              param_info = {
                method_name: method.name,
                resource: method.name.gsub(/_params$/, ""),
                required: require_calls&.map { |c| c[:arguments]&.first },
                permitted: permit_calls&.flat_map { |c| c[:arguments] }
              }

              params << param_info
            end
          end

          params
        end

        def extract_rescue_handlers(klass)
          handlers = []

          klass.methods&.each do |method|
            if method.name == "rescue_from"
              method.calls_made&.each do |call|
                handler = {
                  exception: call[:arguments]&.first,
                  with: extract_rescue_handler(call[:arguments])
                }

                handlers << handler
              end
            end
          end

          handlers
        end

        def extract_controller_concerns(klass)
          klass.mixins&.map { |m| m[:module] || m["module"] }&.select do |name|
            name&.include?("Concern") || name&.include?("able")
          end || []
        end

        def is_api_controller?(klass)
          klass.parent_class == "ActionController::API" ||
            klass.ancestors&.include?("ActionController::API") ||
            klass.name&.include?("Api::")
        end

        def extract_authentication_info(klass)
          auth_info = {
            required: false,
            method: nil,
            skip_actions: []
          }

          # Check for authentication filters
          klass.methods&.each do |method|
            if AUTHENTICATION_METHODS.include?(method.name)
              auth_info[:required] = true
              auth_info[:method] = method.name
            end

            # Check for skip filters
            if method.name.start_with?("skip_") && method.name.include?("auth")
              method.calls_made&.each do |call|
                actions = extract_filter_option(call[:arguments], :only) || []
                auth_info[:skip_actions].concat(actions)
              end
            end
          end

          auth_info
        end

        def infer_routes(klass)
          resource_name = infer_resource_name(klass)
          routes = []

          klass.methods&.each do |method|
            next unless method.visibility == "public"

            route = case method.name
            when "index"
              {path: "/#{resource_name}", method: "GET", action: "index"}
            when "show"
              {path: "/#{resource_name}/:id", method: "GET", action: "show"}
            when "new"
              {path: "/#{resource_name}/new", method: "GET", action: "new"}
            when "create"
              {path: "/#{resource_name}", method: "POST", action: "create"}
            when "edit"
              {path: "/#{resource_name}/:id/edit", method: "GET", action: "edit"}
            when "update"
              {path: "/#{resource_name}/:id", method: ["PUT", "PATCH"], action: "update"}
            when "destroy"
              {path: "/#{resource_name}/:id", method: "DELETE", action: "destroy"}
            end

            routes << route if route
          end

          routes
        end

        def categorize_action(name)
          if REST_ACTIONS.include?(name)
            "rest"
          elsif name.start_with?("api_")
            "api"
          elsif name.end_with?("_callback")
            "webhook"
          else
            "custom"
          end
        end

        def infer_http_verb(action_name)
          case action_name
          when "index", "show", "new", "edit"
            "GET"
          when "create"
            "POST"
          when "update"
            ["PUT", "PATCH"]
          when "destroy", "delete"
            "DELETE"
          else
            "GET"  # Default assumption
          end
        end

        def extract_response_format(method)
          formats = []

          method.calls_made&.each do |call|
            case call[:method]
            when "render"
              formats << if call[:arguments]&.any? { |arg| arg.include?("json") }
                "json"
              elsif call[:arguments]&.any? { |arg| arg.include?("xml") }
                "xml"
              else
                "html"
              end
            when "respond_to"
              formats << "multiple"
            end
          end

          formats.uniq
        end

        def requires_authentication?(method)
          # Simple heuristic - check if method calls authentication methods
          method.calls_made&.any? do |call|
            AUTHENTICATION_METHODS.include?(call[:method])
          end || false
        end

        def extract_filter_option(arguments, option)
          return nil unless arguments

          arguments.each do |arg|
            if arg.is_a?(Hash) && arg[option]
              return Array(arg[option])
            elsif arg.include?("#{option}:")
              # Parse string representation
              value = arg.split("#{option}:").last.strip
              return value.split(",").map(&:strip)
            end
          end

          nil
        end

        def extract_filter_conditions(arguments)
          conditions = {}

          arguments&.each do |arg|
            if arg.include?("if:")
              conditions[:if] = arg.split("if:").last.strip
            elsif arg.include?("unless:")
              conditions[:unless] = arg.split("unless:").last.strip
            end
          end

          conditions
        end

        def extract_rescue_handler(arguments)
          arguments&.each do |arg|
            if arg.include?("with:")
              return arg.split("with:").last.strip
            end
          end

          nil
        end

        def calculate_rest_compliance(controller_info)
          rest_actions = controller_info.actions.select do |a|
            if a.is_a?(Hash)
              a[:type] == "rest"
            else
              REST_ACTIONS.include?(a.to_s)
            end
          end

          return 0.0 if controller_info.actions.empty?

          # Calculate compliance score
          rest_coverage = rest_actions.size.to_f / REST_ACTIONS.size
          rest_ratio = rest_actions.size.to_f / controller_info.actions.size

          ((rest_coverage * 0.6) + (rest_ratio * 0.4)).round(2)
        end

        def calculate_controller_complexity(controller_info)
          score = 0

          # Base complexity from action count
          score += controller_info.action_count * 2

          # Add filter complexity
          score += controller_info.filter_count * 3

          # Add complexity from action complexity
          controller_info.actions.each do |action|
            score += if action.is_a?(Hash)
              action[:complexity] || 1
            else
              # Simple string action, default complexity of 1
              1
            end
          end

          # Add complexity for non-RESTful actions
          non_rest = controller_info.actions.count do |a|
            if a.is_a?(Hash)
              a[:type] != "rest"
            else
              !REST_ACTIONS.include?(a.to_s)
            end
          end
          score += non_rest * 2

          [score, 100].min
        end

        def detect_controller_issues(controller_info, klass)
          issues = []

          # Check for fat controller
          if controller_info.actions.any? { |a| a.is_a?(Hash) && (a[:complexity] || 0) > 10 }
            issues << {
              type: "fat_controller",
              severity: "high",
              message: "Controller has complex actions, consider moving logic to services or models"
            }
          end

          # Check for missing strong parameters
          if controller_info.actions.any? { |a| a.is_a?(Hash) ? %w[create update].include?(a[:name]) : %w[create update].include?(a.to_s) } &&
              controller_info.strong_parameters.empty?
            issues << {
              type: "missing_strong_parameters",
              severity: "high",
              message: "Controller has create/update actions but no strong parameters defined"
            }
          end

          # Check for missing authentication
          if !controller_info.authentication[:required] &&
              !controller_info.name.include?("Public") &&
              !controller_info.name.include?("Session")
            issues << {
              type: "missing_authentication",
              severity: "medium",
              message: "Controller does not appear to require authentication"
            }
          end

          # Check for non-RESTful design
          if controller_info.rest_compliance < 0.5
            issues << {
              type: "non_restful",
              severity: "low",
              message: "Controller has low REST compliance, consider restructuring actions"
            }
          end

          # Check for missing error handling
          if controller_info.rescue_handlers.empty? && controller_info.action_count > 3
            issues << {
              type: "missing_error_handling",
              severity: "medium",
              message: "Controller has no rescue_from handlers for error handling"
            }
          end

          issues
        end
      end
    end
  end
end
