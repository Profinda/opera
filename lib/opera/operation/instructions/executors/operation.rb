# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Operation < Executor
          def call(instruction)
            instruction[:kind] = :step
            operation_result = super
            save_information(operation_result)

            if operation_result.success?
              add_instruction_output(instruction, operation_result.output)
            else
              result.add_errors(operation_result.errors)
            end

            execution = result.executions.pop
            result.add_execution(execution => operation_result.executions) unless production_mode?

            operation_result
          end

          private

          def save_information(operation_result)
            return unless operation_result.respond_to?(:information)

            result.add_information(operation_result.information)
          end
        end
      end
    end
  end
end
