# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Benchmark < Executor
          def call(instruction)
            benchmark = ::Benchmark.measure do
              instruction[:kind] = :step
              super
            end

            result.add_information(benchmark_key(instruction) => { real: benchmark.real, total: benchmark.total })
          end

          private

          def benchmark_key(instruction)
            instruction[:method] || instruction[:label] || instruction[:instructions].map { |e| e[:method] }.join('-').to_sym
          end
        end
      end
    end
  end
end
