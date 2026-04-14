# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class FinishIf < Executor
          def call(instruction)
            operation.finish! if execute_step(instruction)
          end
        end
      end
    end
  end
end
