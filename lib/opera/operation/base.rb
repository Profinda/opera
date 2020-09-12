# frozen_string_literal: true

module Opera
  module Operation
    class Base
      extend Gem::Deprecate
      include Opera::Operation::Builder

      attr_accessor :context
      attr_reader :params, :dependencies, :result

      def initialize(params: {}, dependencies: {})
        @context = {}
        @finished = false
        @result = Result.new
        @params = params.freeze
        @dependencies = dependencies.freeze
      end

      def config
        self.class.config
      end

      def finish
        finish!
      end

      deprecate :finish, :finish!, 2019, 6

      def finish!
        @finished = true
      end

      def finished?
        @finished
      end

      class << self
        def call(args = {})
          operation = new(params: args.fetch(:params, {}), dependencies: args.fetch(:dependencies, {}))
          executor = Executor.new(operation)
          executor.evaluate_instructions(instructions)
          executor.result
        end

        def config
          @config ||= Config.new
        end

        def configure
          yield config
        end

        def reporter
          config.reporter
        end
      end
    end
  end
end
