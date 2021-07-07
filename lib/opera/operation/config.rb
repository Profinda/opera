# frozen_string_literal: true

module Opera
  module Operation
    class Config
      attr_accessor :transaction_class, :transaction_method, :transaction_options, :reporter

      def initialize
        @transaction_class = self.class.transaction_class
        @transaction_method = self.class.transaction_method || :transaction
        @transaction_options = self.class.transaction_options
        @reporter = custom_reporter || self.class.reporter
      end

      def configure
        yield self
      end

      def custom_reporter
        Rails.application.config.x.reporter.presence if defined?(Rails)
      end

      class << self
        attr_accessor :transaction_class, :transaction_method, :transaction_options, :reporter

        def configure
          yield self
        end
      end
    end
  end
end
