# frozen_string_literal: true

module ProFinda
  module Operation
    module Instructions
      module Executors
        class Success < Executor
          def call(instruction)
            instruction[:kind] = :step
            super
          end

          def break_condition
            operation.finished?
          end
        end
      end
    end
  end
end
