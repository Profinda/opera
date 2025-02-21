# frozen_string_literal: true

module Opera
  module Operation
    class Config
      DEVELOPMENT_MODE = :development
      PRODUCTION_MODE = :production

      attr_accessor :transaction_class, :transaction_method, :transaction_options, 
                    :instrumentation_class, :instrumentation_method, :instrumentation_options, :mode, :reporter

      def initialize
        @transaction_class = self.class.transaction_class
        @transaction_method = self.class.transaction_method || :transaction
        @transaction_options = self.class.transaction_options

        @instrumentation_class = self.class.instrumentation_class
        @instrumentation_method = self.class.instrumentation_method || :instrument
        @instrumentation_options = self.class.instrumentation_options || {}

        @mode = self.class.mode || DEVELOPMENT_MODE
        @reporter = custom_reporter || self.class.reporter

        validate!
      end

      def configure
        yield self
      end

      def custom_reporter
        Rails.application.config.x.reporter.presence if defined?(Rails)
      end

      private

      def validate!
        unless [DEVELOPMENT_MODE, PRODUCTION_MODE].include?(mode)
          raise ArgumentError, 'Mode is incorrect. Can be either: development or production' 
        end
      end

      class << self
        attr_accessor :transaction_class, :transaction_method, :transaction_options, 
                      :instrumentation_class, :instrumentation_method, :instrumentation_options, :mode, :reporter

        def configure
          yield self
        end

        def development_mode?
          mode == DEFAULT_MODE
        end

        def production_mode?
          mode == PRODUCTION_MODE
        end
      end
    end
  end
end
