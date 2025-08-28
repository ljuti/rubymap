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
          when nil then "public"  # Handle missing visibility
          else
            # Invalid visibility type
            if errors && !visibility.is_a?(String) && !visibility.is_a?(Symbol)
              error = Normalizer::NormalizedError.new(
                type: "validation",
                message: "invalid visibility: #{visibility}",
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
