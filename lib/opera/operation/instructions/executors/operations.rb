# frozen_string_literal: true

module ProFinda
  module Operation
    module Instructions
      module Executors
        class Operations < Executor
          class WrongOperationsResultError < ProFinda::Error; end

          # rubocop:disable Metrics/MethodLength
          def call(instruction)
            instruction[:kind] = :step
            operations_results = super

            return if result.exceptions.any?

            case operations_results
            when Array
              operations_results.each do |operation_result|
                raise_error unless operation_result.is_a?(ProFinda::Operation::Result)
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
            result.executions << { execution => results.map(&:executions) }
          end

          def raise_error
            raise WrongOperationsResultError, 'Have to return array of ProFinda::Operation::Result'
          end
        end
      end
    end
  end
end
