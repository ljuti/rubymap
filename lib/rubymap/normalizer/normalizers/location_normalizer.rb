# frozen_string_literal: true

module Rubymap
  class Normalizer
    module Normalizers
      # Handles location normalization following Strategy pattern
      class LocationNormalizer
        def normalize(location)
          return nil unless location
          
          NormalizedLocation.new(
            file: location[:file] || location["file"],
            line: (location[:line] || location["line"]).to_i
          )
        end
      end
    end
  end
end