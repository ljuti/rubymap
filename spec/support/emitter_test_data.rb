# frozen_string_literal: true

# EmitterTestData provides standardized test data for emitter specs
# Following FactoryBot patterns for maintainable and realistic test data
module EmitterTestData
  class << self
    def basic_codebase
      {
        metadata: {
          project_name: "TestApp",
          ruby_version: "3.2.0", 
          mapping_date: "2023-12-01T10:00:00Z",
          total_classes: 3,
          total_methods: 8,
          total_modules: 1
        },
        classes: [
          basic_user_class,
          basic_controller_class,
          basic_service_class
        ],
        modules: [
          basic_helper_module
        ],
        graphs: {
          inheritance: [
            {from: "User", to: "ApplicationRecord", type: "inherits"},
            {from: "Admin::UsersController", to: "ApplicationController", type: "inherits"}
          ],
          dependencies: [
            {from: "Admin::UsersController", to: "User", type: "depends_on"},
            {from: "UserService", to: "User", type: "depends_on"}
          ]
        }
      }
    end

    def rails_application
      basic_codebase.merge(
        metadata: basic_codebase[:metadata].merge(
          framework: "Rails",
          version: "7.0.0",
          total_classes: 15,
          total_methods: 75
        ),
        classes: [
          detailed_user_model,
          users_controller,
          admin_users_controller,
          user_service,
          user_serializer
        ],
        modules: [
          authentication_module,
          authorization_module
        ]
      )
    end

    def complex_inheritance_hierarchy
      {
        metadata: basic_metadata,
        classes: [
          {
            fqname: "BaseClass",
            type: "class", 
            superclass: nil,
            file: "lib/base_class.rb",
            line: 1,
            instance_methods: ["base_method"],
            documentation: "Base class for the hierarchy"
          },
          {
            fqname: "MiddleClass", 
            type: "class",
            superclass: "BaseClass",
            file: "lib/middle_class.rb", 
            line: 1,
            instance_methods: ["middle_method"],
            documentation: "Middle tier class"
          },
          {
            fqname: "LeafClassA",
            type: "class",
            superclass: "MiddleClass", 
            file: "lib/leaf_a.rb",
            line: 1,
            instance_methods: ["leaf_a_method"],
            documentation: "First leaf class"
          },
          {
            fqname: "LeafClassB",
            type: "class", 
            superclass: "MiddleClass",
            file: "lib/leaf_b.rb",
            line: 1, 
            instance_methods: ["leaf_b_method"],
            documentation: "Second leaf class"
          }
        ],
        graphs: {
          inheritance: [
            {from: "MiddleClass", to: "BaseClass", type: "inherits"},
            {from: "LeafClassA", to: "MiddleClass", type: "inherits"},
            {from: "LeafClassB", to: "MiddleClass", type: "inherits"}
          ]
        }
      }
    end

    def with_sensitive_information
      basic_codebase.merge(
        classes: [
          {
            fqname: "User",
            type: "class",
            superclass: "ApplicationRecord", 
            file: "/home/developer/secret_project/app/models/user.rb",
            line: 1,
            instance_methods: ["save", "set_password", "api_secret_token", "validate"],
            documentation: "Contains user password and sensitive data",
            constants: ["DATABASE_PASSWORD", "API_SECRET"]
          },
          {
            fqname: "InternalService",
            type: "class", 
            file: "/Users/dev/company/app/services/internal_service.rb",
            line: 1,
            instance_methods: ["internal_api_call", "process_user_token"],
            documentation: "Internal service with API tokens"
          }
        ]
      )
    end

    def with_absolute_paths
      basic_codebase.merge(
        classes: basic_codebase[:classes].map do |klass|
          klass.merge(
            file: "/Users/developer/projects/myapp/#{klass[:file]}"
          )
        end
      )
    end

    def large_class_with_many_methods
      {
        metadata: basic_metadata,
        classes: [
          {
            fqname: "LargeClass",
            type: "class",
            file: "lib/large_class.rb",
            line: 1,
            instance_methods: (1..50).map { |i| "method_#{i}" },
            class_methods: (1..20).map { |i| "class_method_#{i}" },
            constants: %w[CONSTANT_1 CONSTANT_2 CONSTANT_3],
            documentation: "A very large class with many methods " * 100, # Long documentation
            metrics: {
              complexity_score: 8.5,
              lines_of_code: 2000,
              method_count: 70
            }
          }
        ]
      }
    end

    def massive_codebase
      classes = (1..1000).map do |i|
        {
          fqname: "Class#{i}",
          type: "class",
          file: "lib/class_#{i}.rb",
          line: 1,
          instance_methods: (1..10).map { |j| "method_#{j}" },
          documentation: "Auto-generated class #{i}"
        }
      end

      {
        metadata: basic_metadata.merge(
          total_classes: 1000,
          total_methods: 10000
        ),
        classes: classes
      }
    end

    def malformed_codebase
      {
        # Missing metadata
        classes: [
          {
            # Missing required fields like fqname
            type: "class",
            instance_methods: nil, # Null instead of array
            file: "", # Empty file path
          }
        ],
        graphs: nil # Null graphs
      }
    end

    private

    def basic_metadata
      {
        project_name: "TestApp",
        ruby_version: "3.2.0",
        mapping_date: "2023-12-01T10:00:00Z",
        total_classes: 1,
        total_methods: 5
      }
    end

    def basic_user_class
      {
        fqname: "User",
        type: "class",
        superclass: "ApplicationRecord",
        file: "app/models/user.rb", 
        line: 1,
        instance_methods: ["save", "full_name", "active?"],
        class_methods: ["find_by_email"],
        documentation: "Represents a user in the system"
      }
    end

    def basic_controller_class
      {
        fqname: "Admin::UsersController",
        type: "class", 
        superclass: "ApplicationController",
        file: "app/controllers/admin/users_controller.rb",
        line: 3,
        instance_methods: ["index", "show", "create"],
        documentation: "Admin interface for managing users"
      }
    end

    def basic_service_class
      {
        fqname: "UserService",
        type: "class",
        file: "app/services/user_service.rb",
        line: 1, 
        instance_methods: ["create_user", "update_user"],
        documentation: "Service for user operations"
      }
    end

    def basic_helper_module
      {
        fqname: "ApplicationHelper",
        type: "module", 
        file: "app/helpers/application_helper.rb",
        line: 1,
        instance_methods: ["format_date", "truncate_text"],
        documentation: "Common helper methods"
      }
    end

    def detailed_user_model
      basic_user_class.merge(
        instance_methods: [
          "save", "update", "destroy", "valid?", "full_name", 
          "email_confirmed?", "active?", "admin?", "reset_password"
        ],
        class_methods: ["find_by_email", "active_users", "admins", "create_with_defaults"],
        associations: {
          has_many: ["posts", "comments"],
          belongs_to: ["organization"] 
        },
        validations: ["presence :email", "uniqueness :email", "format :email"],
        callbacks: ["before_save :normalize_email", "after_create :send_welcome_email"],
        metrics: {
          complexity_score: 4.2,
          public_api_surface: 12,
          test_coverage: 95.0,
          lines_of_code: 150
        }
      )
    end

    def users_controller
      {
        fqname: "UsersController", 
        type: "class",
        superclass: "ApplicationController",
        file: "app/controllers/users_controller.rb",
        line: 1,
        instance_methods: ["index", "show", "new", "create", "edit", "update", "destroy"],
        before_actions: ["authenticate_user!", "set_user"],
        documentation: "RESTful controller for user management"
      }
    end

    def admin_users_controller
      basic_controller_class.merge(
        before_actions: ["authenticate_admin!", "set_user"],
        instance_methods: ["index", "show", "new", "create", "edit", "update", "destroy", "toggle_admin"]
      )
    end

    def user_service
      {
        fqname: "UserService",
        type: "class", 
        file: "app/services/user_service.rb",
        line: 1,
        instance_methods: [
          "create_user", "update_user", "deactivate_user", 
          "send_password_reset", "confirm_email"
        ],
        documentation: "Business logic for user operations",
        dependencies: ["User", "EmailService", "NotificationService"]
      }
    end

    def user_serializer
      {
        fqname: "UserSerializer",
        type: "class",
        superclass: "ApplicationSerializer", 
        file: "app/serializers/user_serializer.rb",
        line: 1,
        instance_methods: ["attributes", "relationships"],
        class_methods: ["serialize_collection"],
        documentation: "JSON serialization for User model"
      }
    end

    def authentication_module  
      {
        fqname: "Authentication",
        type: "module",
        file: "app/modules/authentication.rb",
        line: 1,
        instance_methods: ["authenticate!", "current_user", "signed_in?", "sign_out"],
        documentation: "Handles user authentication logic"
      }
    end

    def authorization_module
      {
        fqname: "Authorization", 
        type: "module",
        file: "app/modules/authorization.rb", 
        line: 1,
        instance_methods: ["authorize!", "can?", "cannot?", "admin_required"],
        documentation: "Handles user authorization and permissions"
      }
    end
  end
end