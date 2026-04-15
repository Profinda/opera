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
        instructions.each do |instruction|
          evaluate_instruction(instruction)
          break if break_condition
        end
      end

      # Executes the operation method named in the instruction, instruments it,
      # and records the execution. This is the shared primitive that all executors
      # use to invoke a step method without mutating the instruction hash.
      def execute_step(instruction)
        method = instruction[:method]

        Instrumentation.new(operation).instrument(name: "##{method}", level: :step) do
          result.add_execution(method) unless production_mode?
          operation.send(method)
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
        when :finish_if
          Instructions::Executors::FinishIf.new(operation).call(instruction)
        when :within
          Instructions::Executors::Within.new(operation).call(instruction)
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

      def production_mode?
        config.mode == Config::PRODUCTION_MODE
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
        context[:"#{instruction[:method]}_output"] = output
      end
    end
  end
end
