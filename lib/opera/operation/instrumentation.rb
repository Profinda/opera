# frozen_string_literal: true

module Opera
  module Operation
    class Instrumentation
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def instrument(name:, level: :operation)
        return yield if !instrumentation_enabled?
        return yield if level == :step && instrumentation_level != :step

        instrumentation_class.send(instrumentation_method, name, **instrumentation_options.except(:level)) do
          yield
        end
      end

      private

      def instrumentation_options
        config.instrumentation_options
      end

      def instrumentation_method
        config.instrumentation_method
      end

      def instrumentation_class
        config.instrumentation_class
      end

      def instrumentation_enabled?
        !!config.instrumentation_class
      end

      def instrumentation_level
        instrumentation_options[:level] || :operation
      end
    end
  end
end
