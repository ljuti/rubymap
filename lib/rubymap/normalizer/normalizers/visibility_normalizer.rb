# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Normalizers
      # Handles visibility normalization following Strategy pattern
      class VisibilityNormalizer
        def normalize(visibility, errors = nil)
          case visibility
          when :public, "public" then "public"
          when :private, "private" then "private"
          when :protected, "protected" then "protected"
          when nil then "public"  # nil is valid, defaults to public
          when ""
            # Empty string is invalid
            if errors
              error = Normalizer::NormalizedError.new(
                type: "validation",
                message: "invalid visibility: ",
                data: {visibility: visibility}
              )
              errors << error
            end
            "public"
          when /^\s+$/
            # Whitespace-only is invalid
            if errors
              error = Normalizer::NormalizedError.new(
                type: "validation",
                message: "invalid visibility: #{visibility}",
                data: {visibility: visibility}
              )
              errors << error
            end
            "public"
          else
            # Invalid visibility value - add error
            if errors
              # Format message based on type
              message = case visibility
              when Symbol
                "invalid visibility: #{visibility}"
              when String
                "invalid visibility: #{visibility}"
              else
                "invalid visibility: #{visibility}"
              end
              
              error = Normalizer::NormalizedError.new(
                type: "validation",
                message: message,
                data: {visibility: visibility}
              )
              errors << error
            end
            "public"
          end
        end

        def infer_from_name(name)
          return "private" if name.to_s.start_with?("_")
          "public"
        end

        def get_most_restrictive(visibilities)
          visibilities = visibilities.compact.uniq

          # Order by restrictiveness: private > protected > public
          if visibilities.include?("private")
            "private"
          elsif visibilities.include?("protected")
            "protected"
          else
            "public"
          end
        end
      end
    end
  end
end
