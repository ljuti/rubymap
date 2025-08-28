# frozen_string_literal: true

module Rubymap
  class Extractor
    # Information about method aliases
    class AliasInfo
      attr_accessor :new_name, :original_name, :location, :namespace

      def initialize(new_name:, original_name:, location: nil, namespace: nil)
        @new_name = new_name
        @original_name = original_name
        @location = location
        @namespace = namespace
      end
    end
  end
end
