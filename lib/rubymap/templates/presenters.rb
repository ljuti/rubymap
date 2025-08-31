# frozen_string_literal: true

require_relative "presenters/base_presenter"
require_relative "presenters/class_presenter"
require_relative "presenters/module_presenter"
require_relative "presenters/method_presenter"

module Rubymap
  module Templates
    module Presenters
      # Factory method to create appropriate presenter
      def self.for(object)
        case object
        when Hash
          type = object[:type] || object["type"]
          case type
          when "class"
            ClassPresenter.new(object)
          when "module"
            ModulePresenter.new(object)
          when "method"
            MethodPresenter.new(object)
          else
            BasePresenter.new(object)
          end
        else
          BasePresenter.new(object)
        end
      end
    end
  end
end
