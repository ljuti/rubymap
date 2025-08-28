# frozen_string_literal: true

require "rubymap"
require "tempfile"
require "tmpdir"
require "yaml"
require "json"
require "fileutils"

# Shared contexts and helpers for Rubymap specs
RSpec.shared_context "temporary directory" do
  let(:temp_dir) { Dir.mktmpdir("rubymap_test") }
  
  after do
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end
  
  def create_temp_file(path, content)
    full_path = File.join(temp_dir, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
    full_path
  end
end

RSpec.shared_context "sample Ruby code" do
  let(:simple_class_code) do
    <<~RUBY
      class User
        attr_reader :name, :email
        
        def initialize(name, email)
          @name = name
          @email = email
        end
        
        def full_name
          "\#{@name} <\#{@email}>"
        end
        
        private
        
        def validate_email
          @email.include?('@')
        end
      end
    RUBY
  end

  let(:inheritance_code) do
    <<~RUBY
      class ApplicationRecord
        def save
          # base implementation
        end
      end
      
      class User < ApplicationRecord
        include Comparable
        extend ClassMethods
        
        def full_name
          "\#{first_name} \#{last_name}"
        end
      end
    RUBY
  end

  let(:module_code) do
    <<~RUBY
      module Searchable
        extend ActiveSupport::Concern
        
        included do
          scope :published, -> { where(published: true) }
        end
        
        module ClassMethods
          def search(query)
            where("name ILIKE ?", "%\#{query}%")
          end
        end
        
        def searchable_fields
          [:name, :description]
        end
      end
    RUBY
  end

  let(:rails_model_code) do
    <<~RUBY
      class User < ApplicationRecord
        validates :email, presence: true, uniqueness: true
        validates :name, presence: true, length: { minimum: 2 }
        
        has_many :posts, dependent: :destroy
        belongs_to :organization, optional: true
        
        scope :active, -> { where(active: true) }
        
        before_save :normalize_email
        after_create :send_welcome_email
        
        private
        
        def normalize_email
          self.email = email.downcase.strip
        end
      end
    RUBY
  end
end

RSpec.shared_context "sample project structure" do
  include_context "temporary directory"
  
  let(:project_structure) do
    {
      "app/models/user.rb" => simple_class_code,
      "app/models/application_record.rb" => "class ApplicationRecord < ActiveRecord::Base; end",
      "app/controllers/users_controller.rb" => <<~RUBY,
        class UsersController < ApplicationController
          def index
            @users = User.all
          end
          
          def show
            @user = User.find(params[:id])
          end
        end
      RUBY
      "lib/utilities/string_helper.rb" => <<~RUBY,
        module Utilities
          module StringHelper
            def titleize(str)
              str.split.map(&:capitalize).join(' ')
            end
          end
        end
      RUBY
      "config/routes.rb" => <<~RUBY
        Rails.application.routes.draw do
          resources :users, only: [:index, :show]
        end
      RUBY
    }
  end
  
  before do
    project_structure.each do |path, content|
      create_temp_file(path, content)
    end
  end
end

# Custom matchers for Rubymap specs
RSpec::Matchers.define :have_class do |expected_name|
  match do |result|
    result.classes.any? { |cls| cls.name == expected_name }
  end
  
  description { "have class named #{expected_name}" }
  failure_message { "expected result to include class #{expected_name}, but got classes: #{result.classes.map(&:name)}" }
end

RSpec::Matchers.define :have_method do |expected_name|
  match do |result|
    result.methods.any? { |method| method.name == expected_name }
  end
  
  description { "have method named #{expected_name}" }
  failure_message { "expected result to include method #{expected_name}, but got methods: #{result.methods.map(&:name)}" }
end

RSpec::Matchers.define :have_association do |expected_name|
  match do |model|
    model.associations.any? { |assoc| assoc.name == expected_name }
  end
  
  description { "have association named #{expected_name}" }
end

RSpec::Matchers.define :have_validation do |attribute, type|
  match do |model|
    model.validations.any? { |val| val.attribute == attribute && val.type == type }
  end
  
  description { "have #{type} validation on #{attribute}" }
end

# Helper methods available in all specs
module RubymapSpecHelpers
  def parse_json_output(output)
    JSON.parse(output)
  rescue JSON::ParserError => e
    raise "Invalid JSON output: #{e.message}\nOutput: #{output}"
  end
  
  def parse_yaml_output(output) 
    YAML.safe_load(output)
  rescue Psych::SyntaxError => e
    raise "Invalid YAML output: #{e.message}\nOutput: #{output}"
  end
  
  def create_config_file(config_hash, format: :yaml)
    case format
    when :yaml
      config_hash.to_yaml
    when :json
      config_hash.to_json
    else
      raise ArgumentError, "Unsupported config format: #{format}"
    end
  end
  
  def stub_file_system(file_structure)
    file_structure.each do |path, content|
      allow(File).to receive(:read).with(path).and_return(content)
      allow(File).to receive(:exist?).with(path).and_return(true)
    end
  end
  
  def expect_no_errors(result)
    expect(result.errors).to be_empty, 
      "Expected no errors, but got: #{result.errors.map(&:message)}"
  end
  
  def expect_performance_within(duration, &block)
    start_time = Time.now
    yield
    elapsed = Time.now - start_time
    expect(elapsed).to be < duration, 
      "Expected operation to complete within #{duration}s, but took #{elapsed}s"
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  
  # Include helper modules
  config.include RubymapSpecHelpers
  
  # Global setup and teardown
  config.before(:suite) do
    # Clean up any existing test artifacts
    FileUtils.rm_rf("spec/tmp") if Dir.exist?("spec/tmp")
    FileUtils.mkdir_p("spec/tmp")
  end
  
  config.after(:suite) do
    # Clean up test artifacts
    FileUtils.rm_rf("spec/tmp") if Dir.exist?("spec/tmp")
  end
  
  # Configure shared behavior
  config.shared_context_metadata_behavior = :apply_to_host_groups
  
  # Filtering for different test types
  config.define_derived_metadata(file_path: %r{/spec/integration/}) do |metadata|
    metadata[:type] = :integration
  end
  
  config.define_derived_metadata(file_path: %r{/spec/unit/}) do |metadata|
    metadata[:type] = :unit
  end
  
  config.define_derived_metadata(file_path: %r{/spec/.*_spec\.rb}) do |metadata|
    metadata[:type] ||= :unit
  end
  
  # Performance test configuration
  config.around(:each, :performance) do |example|
    # Set up performance monitoring
    start_memory = `ps -o pid,rss -p #{Process.pid}`.split.last.to_i
    start_time = Time.now
    
    example.run
    
    end_time = Time.now
    end_memory = `ps -o pid,rss -p #{Process.pid}`.split.last.to_i
    
    duration = end_time - start_time
    memory_delta = end_memory - start_memory
    
    puts "Performance: #{duration.round(3)}s, Memory: #{memory_delta}KB" if ENV["SHOW_PERFORMANCE"]
  end
  
  # Verbose error output for CI environments
  if ENV["CI"]
    config.formatter = :documentation
    config.default_formatter = "doc"
  end
  
  # Configure warnings
  config.warnings = true
  
  # Order specs randomly but allow deterministic runs
  config.order = :random
  Kernel.srand config.seed if config.seed
end
