# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Success < Executor
          def call(instruction)
            if instruction[:instructions]
              evaluate_instructions(instruction[:instructions])
            else
              execute_step(instruction)
            end
          end

          def break_condition
            operation.finished?
          end
        end
      end
    end
  end
end
