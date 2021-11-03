# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class FinishIf < Executor
          def call(instruction)
            instruction[:kind] = :step
            operation.finish! if super
          end
        end
      end
    end
  end
end
