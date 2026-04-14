# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Around < Executor
          def call(instruction)
            wrapper_method = instruction[:label]
            nested_instructions = instruction[:instructions]

            raise ArgumentError, 'around requires a method name' unless wrapper_method
            raise ArgumentError, 'around requires a block with at least one instruction' if nested_instructions.nil?

            operation.send(wrapper_method) do
              super
            end
          end
        end
      end
    end
  end
end
