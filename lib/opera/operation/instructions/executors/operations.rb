# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Operations < Executor
          class WrongOperationsResultError < Opera::Error; end

          # rubocop:disable Metrics/MethodLength
          def call(instruction)
            instruction[:kind] = :step
            operations_results = super

            return if result.exceptions.any?

            case operations_results
            when Array
              operations_results.each do |operation_result|
                raise_error unless operation_result.is_a?(Opera::Operation::Result)
              end

              failures = operations_results.select(&:failure?)

              if failures.any?
                add_failures(failures)
              else
                add_results(instruction, operations_results)
              end
            else
              raise_error
            end
          end
          # rubocop:enable Metrics/MethodLength

          private

          def add_failures(failures)
            failures.each do |failure|
              result.add_errors(failure.errors)
              result.add_exceptions(failure.exceptions)
            end
          end

          def add_results(instruction, results)
            add_instruction_output(instruction, results.map(&:output))
            execution = result.executions.pop
            result.add_execution(execution => results.map(&:executions))
          end

          def raise_error
            raise WrongOperationsResultError, 'Have to return array of Opera::Operation::Result'
          end
        end
      end
    end
  end
end
