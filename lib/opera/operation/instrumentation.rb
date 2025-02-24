# frozen_string_literal: true

module Opera
  module Operation
    class Instrumentation
      class Base
        def self.instrument(operation, name:, level: :operation)
          raise NotImplementedError, "#{self.class} must implement #instrument"
        end
      end

      attr_reader :operation

      def initialize(operation)
        @operation = operation
      end

      def instrument(name:, level: :operation)
        return yield if !instrumentation_enabled?
        return yield if !instrumentation_compatible?

        instrumentation_class.instrument(operation, name: name, level: level) do
          yield
        end
      end

      private

      def config
        operation.config
      end

      def instrumentation_class
        config.instrumentation_class
      end

      def instrumentation_enabled?
        !!config.instrumentation_class
      end

      def instrumentation_compatible?
        config.instrumentation_class.ancestors.include?(Opera::Operation::Instrumentation::Base)
      end
    end
  end
end
