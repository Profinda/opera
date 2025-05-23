# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Step < Executor
          def call(instruction)
            method = instruction[:method]

            Instrumentation.new(operation).instrument(name: "##{method}", level: :step) do
              operation.result.add_execution(method) unless production_mode?
              operation.send(method)
            end
          end
        end
      end
    end
  end
end
