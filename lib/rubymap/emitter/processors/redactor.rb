# frozen_string_literal: true

module Rubymap
  module Emitter
    module Processors
      class Redactor
        DEFAULT_PATTERNS = [
          /password[\s]*[:=]\s*["']([^"']+)["']/i,
          /secret[\s]*[:=]\s*["']([^"']+)["']/i,
          /api[_-]?key[\s]*[:=]\s*["']([^"']+)["']/i,
          /token[\s]*[:=]\s*["']([^"']+)["']/i,
          /private[_-]?key[\s]*[:=]\s*["']([^"']+)["']/i,
          /access[_-]?key[\s]*[:=]\s*["']([^"']+)["']/i
        ].freeze

        SECURITY_LEVELS = {
          minimal: {
            patterns: [
              /password\s*=\s*["']([^"']+)["']/i
            ],
            replacement: "[REDACTED]"
          },
          standard: {
            patterns: DEFAULT_PATTERNS,
            replacement: "[REDACTED]"
          },
          aggressive: {
            patterns: DEFAULT_PATTERNS + [
              /email[\s]*[:=]\s*["']([^"']+)["']/i,
              /username[\s]*[:=]\s*["']([^"']+)["']/i,
              /\/home\/\w+/,
              /\/Users\/\w+/,
              /\b\d{3}-\d{2}-\d{4}\b/,  # SSN pattern
              /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i  # Email
            ],
            replacement: "[REDACTED]"
          }
        }.freeze

        def initialize(rules = nil, security_level: :standard)
          @security_level = security_level
          @rules = rules || load_security_rules(security_level)
          @replacement = SECURITY_LEVELS[security_level][:replacement] || "[REDACTED]"
        end

        def redact(content)
          return content if content.nil? || content.empty?

          redacted = content.dup

          @rules.each do |rule|
            if rule.is_a?(Regexp)
              redacted = redact_pattern(redacted, rule)
            elsif rule.is_a?(Hash)
              redacted = redact_with_rule(redacted, rule)
            end
          end

          # Sanitize file paths
          redacted = sanitize_paths(redacted) if @security_level == :aggressive

          redacted
        end

        def redact_hash(data)
          return data unless data.is_a?(Hash)

          data.transform_values do |value|
            case value
            when String
              redact(value)
            when Hash
              redact_hash(value)
            when Array
              redact_array(value)
            else
              value
            end
          end
        end

        def redact_array(data)
          return data unless data.is_a?(Array)

          data.map do |item|
            case item
            when String
              redact(item)
            when Hash
              redact_hash(item)
            when Array
              redact_array(item)
            else
              item
            end
          end
        end

        private

        def load_security_rules(level)
          SECURITY_LEVELS[level][:patterns] || DEFAULT_PATTERNS
        end

        def redact_pattern(content, pattern)
          content.gsub(pattern) do |match|
            # Preserve the structure but redact the value
            if match.include?("=") || match.include?(":")
              parts = match.split(/[:=]/, 2)
              "#{parts[0]}#{match.include?(":") ? ":" : "="} \"#{@replacement}\""
            else
              @replacement
            end
          end
        end

        def redact_with_rule(content, rule)
          pattern = rule[:pattern]
          replacement = rule[:replacement] || @replacement

          if rule[:preserve_structure]
            content.gsub(pattern) do |match|
              # Keep the key, replace the value
              match.sub(/["']([^"']+)["']/, "\"#{replacement}\"")
            end
          else
            content.gsub(pattern, replacement)
          end
        end

        def sanitize_paths(content)
          # Remove absolute paths, keep relative
          content.gsub(/\/Users\/[^\/\s]+/, "/Users/[USER]")
            .gsub(/\/home\/[^\/\s]+/, "/home/[USER]")
            .gsub(/C:\\Users\\[^\\]+/, "C:\\Users\\[USER]")
            .tr("\\", "/")  # Normalize path separators
        end
      end
    end
  end
end
