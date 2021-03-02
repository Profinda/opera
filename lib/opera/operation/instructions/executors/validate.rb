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

            if dry_result.success?
              output = dry_result.is_a?(Opera::Operation::Result) ? dry_result.output : dry_result
              add_instruction_output(instruction, output.to_h)
            else
              result.add_errors(dry_result.errors)
            end
          end
        end
      end
    end
  end
end
