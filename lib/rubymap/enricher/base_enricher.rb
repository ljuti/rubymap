# frozen_string_literal: true

module Rubymap
  class Enricher
    # Base class for all enricher components
    class BaseEnricher
      def enrich(result, config)
        raise NotImplementedError, "#{self.class} must implement #enrich"
      end
      
      protected
      
      def config_value(config, key, default = nil)
        return default unless config
        config[key] || default
      end
      
      def log(message, level = :info)
        # Placeholder for logging
        # Could be expanded to use actual logging framework
      end
    end
  end
end