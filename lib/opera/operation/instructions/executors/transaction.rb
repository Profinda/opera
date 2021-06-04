# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Transaction < Executor
          class RollbackTransactionError < Opera::Error; end

          def call(instruction)
            arguments = transaction_options.present? ? [transaction_method, transaction_options] : [transaction_method]
            transaction_class.send(arguments) do
              super

              return if !operation.finished? && result.success?

              raise(RollbackTransactionError)
            end
          rescue RollbackTransactionError
            nil
          end

          def transaction_class
            config.transaction_class
          end

          def transaction_method
            config.transaction_method
          end

          def transaction_options
            config.transaction_options
          end
        end
      end
    end
  end
end
