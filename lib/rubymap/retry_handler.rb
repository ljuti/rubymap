# frozen_string_literal: true

module Rubymap
  # Handles retry logic for transient failures in the pipeline.
  #
  # Provides configurable retry mechanisms with exponential backoff for
  # handling temporary failures like file I/O errors, network issues, or
  # transient resource unavailability.
  #
  # @example Basic retry usage
  #   handler = RetryHandler.new(max_retries: 3, base_delay: 0.1)
  #   result = handler.with_retry do
  #     # Code that might fail transiently
  #     File.read(path)
  #   end
  #
  # @example Custom retry conditions
  #   handler = RetryHandler.new do |config|
  #     config.retry_on = [Errno::ENOENT, Timeout::Error]
  #     config.max_retries = 5
  #   end
  class RetryHandler
    DEFAULT_RETRYABLE_ERRORS = [
      Errno::EAGAIN,      # Resource temporarily unavailable
      Errno::ETIMEDOUT,   # Connection timed out
      Errno::ECONNRESET,  # Connection reset by peer
      Errno::EBUSY,       # Resource busy
      Timeout::Error,     # Generic timeout
      IOError             # Generic I/O error
    ].freeze

    attr_reader :max_retries, :base_delay, :max_delay, :exponential_base, :retry_on

    # Initialize a new retry handler
    #
    # @param max_retries [Integer] Maximum number of retry attempts
    # @param base_delay [Float] Initial delay between retries in seconds
    # @param max_delay [Float] Maximum delay between retries
    # @param exponential_base [Float] Base for exponential backoff
    # @param retry_on [Array<Class>] Exception classes to retry on
    def initialize(max_retries: 3, base_delay: 0.1, max_delay: 5.0, exponential_base: 2.0, retry_on: DEFAULT_RETRYABLE_ERRORS)
      @max_retries = max_retries
      @base_delay = base_delay
      @max_delay = max_delay
      @exponential_base = exponential_base
      @retry_on = retry_on
      
      yield self if block_given?
    end

    # Execute a block with retry logic
    #
    # @param error_collector [ErrorCollector, nil] Optional error collector for logging attempts
    # @param context [Hash] Additional context for error reporting
    # @yield The block to execute with retries
    # @return The return value of the block
    # @raise The last exception if all retries are exhausted
    def with_retry(error_collector: nil, **context)
      attempt = 0
      last_error = nil

      begin
        attempt += 1
        yield
      rescue *@retry_on => e
        last_error = e

        if attempt <= @max_retries
          delay = calculate_delay(attempt)
          
          # Log retry attempt if error collector provided
          if error_collector
            error_collector.add_info(
              :runtime,
              "Retry attempt #{attempt}/#{@max_retries} after #{e.class}: #{e.message}",
              **context
            )
          end

          sleep(delay)
          retry
        else
          # Log final failure if error collector provided
          if error_collector
            error_collector.add_error(
              :runtime,
              "Failed after #{@max_retries} retries: #{e.message}",
              severity: :error,
              **context
            )
          end

          raise
        end
      end
    end

    # Check if an error is retryable
    #
    # @param error [Exception] The error to check
    # @return [Boolean] Whether the error is retryable
    def retryable?(error)
      @retry_on.any? { |klass| error.is_a?(klass) }
    end

    # Add additional error classes to retry on
    #
    # @param error_classes [Array<Class>] Error classes to add
    def add_retryable_errors(*error_classes)
      @retry_on.concat(error_classes).uniq!
    end

    private

    def calculate_delay(attempt)
      delay = @base_delay * (@exponential_base ** (attempt - 1))
      [delay, @max_delay].min
    end
  end

  # Module to add retry capability to any class
  module Retryable
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Define a method with automatic retry logic
      #
      # @example
      #   class FileProcessor
      #     include Retryable
      #
      #     retry_method :process_file, max_retries: 5 do |file_path|
      #       File.read(file_path)
      #     end
      #   end
      def retry_method(method_name, **retry_options, &block)
        define_method(method_name) do |*args, **kwargs|
          handler = RetryHandler.new(**retry_options)
          handler.with_retry do
            instance_exec(*args, **kwargs, &block)
          end
        end
      end
    end

    # Instance method for ad-hoc retries
    def with_retry(**options, &block)
      handler = RetryHandler.new(**options)
      handler.with_retry(&block)
    end
  end
end