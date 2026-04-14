# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Within < Executor
          def call(instruction)
            wrapper_method = instruction[:label]
            nested_instructions = instruction[:instructions]

            raise ArgumentError, 'within requires a method name' unless wrapper_method
            raise ArgumentError, 'within requires a block with at least one instruction' if nested_instructions.nil?

            operation.send(wrapper_method) do
              evaluate_instructions(nested_instructions)
            end
          end
        end
      end
    end
  end
end
