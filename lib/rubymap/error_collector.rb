# frozen_string_literal: true

require "json"
require "time"

module Rubymap
  # Centralized error collection and management for the Rubymap pipeline.
  #
  # Provides a unified system for collecting, categorizing, and reporting errors
  # from all pipeline components. Supports error severity levels, context tracking,
  # and comprehensive error summaries.
  #
  # @example Basic usage
  #   collector = ErrorCollector.new
  #   collector.add_error(:parse, "Syntax error in file", severity: :critical)
  #   collector.add_warning(:encoding, "Invalid UTF-8 sequence")
  #   collector.summary # => { total: 2, critical: 1, warning: 1 }
  class ErrorCollector
    # Error severity levels
    SEVERITIES = [:critical, :error, :warning, :info].freeze

    # Error categories for different pipeline stages
    CATEGORIES = [
      :parse,       # Parsing errors
      :encoding,    # Encoding issues
      :dependency,  # Dependency resolution
      :filesystem,  # File system operations
      :memory,      # Memory/performance issues
      :output,      # Output generation
      :config,      # Configuration problems
      :runtime,     # Runtime analysis errors
      :unknown      # Uncategorized errors
    ].freeze

    attr_reader :errors, :max_errors, :fail_fast

    # Initialize a new error collector
    #
    # @param max_errors [Integer, nil] Maximum errors to collect (nil for unlimited)
    # @param fail_fast [Boolean] Whether to raise on critical errors
    def initialize(max_errors: nil, fail_fast: false)
      @errors = []
      @max_errors = max_errors
      @fail_fast = fail_fast
      @error_counts = Hash.new(0)
      @category_counts = Hash.new(0)
    end

    # Add an error to the collection
    #
    # @param category [Symbol] Error category
    # @param message [String] Error message
    # @param severity [Symbol] Error severity (:critical, :error, :warning, :info)
    # @param file [String, nil] Associated file path
    # @param line [Integer, nil] Line number where error occurred
    # @param context [Hash] Additional context information
    # @raise [CriticalError] If fail_fast is true and severity is critical
    def add_error(category, message, severity: :error, file: nil, line: nil, **context)
      return if @max_errors && @errors.size >= @max_errors

      validate_severity(severity)
      validate_category(category)

      error = ErrorInfo.new(
        category: category,
        message: message,
        severity: severity,
        file: file,
        line: line,
        context: context,
        timestamp: Time.now
      )

      @errors << error
      @error_counts[severity] += 1
      @category_counts[category] += 1

      raise CriticalError, error.full_message if @fail_fast && severity == :critical

      error
    end

    # Add a warning (convenience method)
    def add_warning(category, message, **options)
      add_error(category, message, severity: :warning, **options)
    end

    # Add an info message (convenience method)
    def add_info(category, message, **options)
      add_error(category, message, severity: :info, **options)
    end

    # Add a critical error (convenience method)
    def add_critical(category, message, **options)
      add_error(category, message, severity: :critical, **options)
    end

    # Check if there are any errors
    def any?
      @errors.any?
    end

    # Check if there are critical errors
    def critical?
      @error_counts[:critical] > 0
    end

    # Check if error limit has been reached
    def limit_reached?
      @max_errors && @errors.size >= @max_errors
    end

    # Get errors by severity
    def by_severity(severity)
      validate_severity(severity)
      @errors.select { |e| e.severity == severity }
    end

    # Get errors by category
    def by_category(category)
      validate_category(category)
      @errors.select { |e| e.category == category }
    end

    # Get errors for a specific file
    def by_file(file_path)
      @errors.select { |e| e.file == file_path }
    end

    # Get error summary
    def summary
      {
        total: @errors.size,
        by_severity: @error_counts.dup,
        by_category: @category_counts.dup,
        critical: critical?,
        limit_reached: limit_reached?
      }
    end

    # Generate human-readable error report
    def report(verbose: false)
      return "No errors encountered." if @errors.empty?

      lines = ["Error Summary:"]
      lines << "  Total: #{@errors.size} error(s)"

      # Severity breakdown
      SEVERITIES.each do |severity|
        count = @error_counts[severity]
        lines << "  #{severity.capitalize}: #{count}" if count > 0
      end

      lines << ""

      if verbose
        # Detailed error listing
        @errors.group_by(&:category).each do |category, errors|
          lines << "#{category.capitalize} Errors:"
          errors.each do |error|
            lines << "  #{error.formatted_message}"
          end
          lines << ""
        end
      else
        # Condensed listing of critical and errors only
        critical_and_errors = @errors.select { |e| [:critical, :error].include?(e.severity) }
        if critical_and_errors.any?
          lines << "Critical Issues:"
          critical_and_errors.first(10).each do |error|
            lines << "  #{error.formatted_message}"
          end
          if critical_and_errors.size > 10
            lines << "  ... and #{critical_and_errors.size - 10} more"
          end
        end
      end

      lines.join("\n")
    end

    # Clear all collected errors
    def clear
      @errors.clear
      @error_counts.clear
      @category_counts.clear
    end

    # Merge errors from another collector
    def merge!(other_collector)
      other_collector.errors.each do |error|
        add_error(
          error.category,
          error.message,
          severity: error.severity,
          file: error.file,
          line: error.line,
          **error.context
        )
      end
    end

    # Export errors as structured data
    def to_h
      {
        errors: @errors.map(&:to_h),
        summary: summary
      }
    end

    # Export errors as JSON
    def to_json(*args)
      to_h.to_json(*args)
    end

    private

    def validate_severity(severity)
      unless SEVERITIES.include?(severity)
        raise ArgumentError, "Invalid severity: #{severity}. Must be one of: #{SEVERITIES.join(", ")}"
      end
    end

    def validate_category(category)
      unless CATEGORIES.include?(category)
        raise ArgumentError, "Invalid category: #{category}. Must be one of: #{CATEGORIES.join(", ")}"
      end
    end
  end

  # Structured error information
  class ErrorInfo
    attr_reader :category, :message, :severity, :file, :line, :context, :timestamp

    def initialize(category:, message:, severity:, file: nil, line: nil, context: {}, timestamp: Time.now)
      @category = category
      @message = message
      @severity = severity
      @file = file
      @line = line
      @context = context
      @timestamp = timestamp
    end

    # Generate full error message with context
    def full_message
      parts = []
      parts << "[#{@severity.upcase}]"
      parts << "[#{@category}]"
      parts << "#{@file}:#{@line}" if @file && @line
      parts << @file if @file && !@line
      parts << @message
      parts.compact.join(" ")
    end

    # Generate formatted message for display
    def formatted_message
      if @file && @line
        "#{@message} (#{@file}:#{@line})"
      elsif @file
        "#{@message} (#{@file})"
      else
        @message
      end
    end

    # Convert to hash
    def to_h
      {
        category: @category,
        message: @message,
        severity: @severity,
        file: @file,
        line: @line,
        context: @context,
        timestamp: @timestamp.iso8601
      }
    end
  end

  # Exception raised for critical errors when fail_fast is enabled
  class CriticalError < StandardError; end
end
