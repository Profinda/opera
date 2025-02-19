# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Step < Executor
          def call(instruction)
            method = instruction[:method]

            config.instrumentation_wrapper("#{operation.class.name}##{method}", level: :step) do
              operation.result.add_execution(method) unless production_mode?
              operation.send(method)
            end
          rescue StandardError => exception
            reporter&.error(exception)
            operation.result.add_exception(method, "#{exception.message}, for #{operation.inspect}", classname: operation.class.name)
            operation.result
          end
        end
      end
    end
  end
end
