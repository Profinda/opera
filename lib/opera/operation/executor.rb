# frozen_string_literal: true

module Opera
  module Operation
    class Executor
      attr_reader :operation

      def initialize(operation)
        @operation = operation
      end

      def call(instruction)
        instructions = instruction[:instructions]

        if instructions
          evaluate_instructions(instructions)
        else
          evaluate_instruction(instruction)
        end
      end

      def evaluate_instructions(instructions = [])
        instruction_copy = Marshal.load(Marshal.dump(instructions))

        while instruction_copy.any?
          instruction = instruction_copy.shift
          evaluate_instruction(instruction)
          break if break_condition
        end
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
      def evaluate_instruction(instruction)
        case instruction[:kind]
        when :step
          Instructions::Executors::Step.new(operation).call(instruction)
        when :operation
          Instructions::Executors::Operation.new(operation).call(instruction)
        when :operations
          Instructions::Executors::Operations.new(operation).call(instruction)
        when :success
          Instructions::Executors::Success.new(operation).call(instruction)
        when :validate
          Instructions::Executors::Validate.new(operation).call(instruction)
        when :transaction
          Instructions::Executors::Transaction.new(operation).call(instruction)
        when :benchmark
          Instructions::Executors::Benchmark.new(operation).call(instruction)
        else
          raise(UnknownInstructionError, "Unknown instruction #{instruction[:kind]}")
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity

      def result
        operation.result
      end

      def config
        operation.config
      end

      def context
        operation.context
      end

      def reporter
        config.reporter
      end

      def break_condition
        operation.finished? || result.failure?
      end

      def add_instruction_output(instruction, output = {})
        context["#{instruction[:method]}_output".to_sym] = output
      end
    end
  end
end
