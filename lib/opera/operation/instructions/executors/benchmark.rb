# frozen_string_literal: true

module Opera
  module Operation
    module Instructions
      module Executors
        class Benchmark < Executor
          def call(instruction)
            benchmark = ::Benchmark.measure do
              super
            end

            result.add_information(real: benchmark.real, total: benchmark.total)
          end
        end
      end
    end
  end
end
