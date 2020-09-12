# frozen_string_literal: true

module ProFinda
  module Operation
    module Instructions
      module Executors
        class Step < Executor
          def call(instruction)
            method = instruction[:method]

            operation.result.add_execution(method)
            operation.send(method)
          rescue StandardError => exception
            reporter&.error(exception)
            operation.result.add_exception(method, exception.message, classname: operation.class.name)
          end
        end
      end
    end
  end
end
