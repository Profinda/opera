# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Validate < Executor
          def break_condition
            operation.finished?
          end

          private

          def evaluate_instruction(instruction)
            instruction[:kind] = :step
            validation_result = super

            case validation_result
            when Opera::Operation::Result
              add_instruction_output(instruction, validation_result.output)

              result.add_errors(validation_result.errors) unless validation_result.success?
            when Dry::Validation::Result
              add_instruction_output(instruction, validation_result.to_h)

              result.add_errors(validation_result.errors) unless validation_result.success?
            else
              raise TypeError, "#{validation_result.class} is not a valid result for 'validate' step. " \
                "Please check output of '#{instruction[:method]}' step in #{operation.class.name}"
            end
          end
        end
      end
    end
  end
end
