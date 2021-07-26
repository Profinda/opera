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

        def check_method_availability!(method)
          return if instance_methods(false).none?(method)

          raise(ArgumentError, "Method #{method} is already defined")
        end

        %i[context params dependencies].each do |method|
          define_method("#{method}_reader") do |*attributes, **options|
            attributes.map(&:to_sym).each do |attribute|
              check_method_availability!(attribute)

              define_method(attribute) do
                send(method)[attribute] ||= options[:default]
              end
            end
          end

          define_method("#{method}_writer") do |*attributes|
            attributes.map(&:to_sym).each do |attribute|
              check_method_availability!("#{attribute}=")

              define_method("#{attribute}=") do |value|
                send(method)[attribute] = value
              end
            end
          end

          define_method("#{method}_accessor") do |*attributes, **options|
            send("#{method}_reader", *attributes, **options)
            send("#{method}_writer", *attributes)
          end
        end
      end
    end
  end
end
