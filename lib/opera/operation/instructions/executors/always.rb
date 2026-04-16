# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Always < Executor
          def call(instruction)
            execute_step(instruction)
          end
        end
      end
    end
  end
end
