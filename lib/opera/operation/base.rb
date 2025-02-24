# frozen_string_literal: true

module Opera
  module Operation
    class Base
      include Opera::Operation::Builder

      attr_accessor :context
      attr_reader :params, :dependencies, :result

      def initialize(params: {}, dependencies: {})
        @context = {}
        @finished = false
        @result = Result.new
        @params = params.freeze
        @dependencies = dependencies.freeze
        config
      end

      def config
        self.class.config
      end

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
          Instrumentation.new(operation).instrument(name: self.name, level: :operation) do
            executor.evaluate_instructions(instructions)
          end
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

        def check_method_availability!(method)
          return if instance_methods(false).none?(method)

          raise(ArgumentError, "Method #{method} is already defined")
        end

        def context(&blk)
          AttributesDSL.new(klass: self, block_name: :context, allowed: [:attr_reader, :attr_accessor]).instance_exec(&blk)
        end

        def params(&blk)
          AttributesDSL.new(klass: self, block_name: :params).instance_exec(&blk)
        end

        def dependencies(&blk)
          AttributesDSL.new(klass: self, block_name: :dependencies).instance_exec(&blk)
        end

        # TODO: Delete with newer version
        %i[context params dependencies].each do |method|
          define_method("#{method}_reader") do |*attributes, **options|
            send(method) do
              attr_reader *attributes, **options
            end
          end
        end

        %i[context].each do |method|
          define_method("#{method}_writer") do |*attributes|
            send(method) do
              attr_writer *attributes
            end
          end

          define_method("#{method}_accessor") do |*attributes, **options|
            send(method) do
              attr_reader *attributes, **options
              attr_writer *attributes, **options
            end
          end
        end
      end
    end
  end
end
