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
            dry_result = super

            case dry_result
            when Opera::Operation::Result
              add_instruction_output(instruction, dry_result.to_h)

              unless dry_result.success?
                result.add_errors(dry_result.errors)
                result.add_exceptions(dry_result.exceptions)
              end
            when Dry::Validation::Result
              add_instruction_output(instruction, dry_result.to_h)

              result.add_errors(dry_result.errors) unless dry_result.success?
            else
              exception_message = "#{dry_result.class} is not expected object. Please check: #{dry_result.inspect}"
              result.add_exception(instruction[:method], exception_message, classname: operation.class.name)
            end
          end
        end
      end
    end
  end
end
