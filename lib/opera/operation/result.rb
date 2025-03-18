# frozen_string_literal: true

module Opera
  module Operation
    class Result
      class OutputError < StandardError
        attr_reader :errors

        def initialize(msg, errors = {})
          @errors = errors
          super(msg)
        end
      end

      attr_reader :errors, # Acumulator of errors in validation + steps
                  :information, # Temporal object to store related information
                  :executions # Stacktrace or Pipe of the methods evaludated

      attr_accessor :output # in case of success, it contains the resulting value

      def initialize(output: nil, errors: {})
        @errors = errors
        @information = {}
        @executions = []
        @output = output
      end

      def failure?
        errors.any?
      end

      def success?
        !failure?
      end

      def failures
        errors
      end

      def output!
        raise OutputError.new('Cannot retrieve output from a Failure.', errors) if failure?

        output
      end

      # rubocop:disable Metrics/MethodLength
      def add_error(field, message)
        @errors[field] ||= []
        if message.is_a?(Hash)
          if @errors[field].first&.is_a?(Hash)
            @errors[field].first.merge!(message)
          else
            @errors[field].push(message)
          end
        else
          @errors[field].concat(Array(message))
        end
        @errors[field].uniq!
      end
      # rubocop:enable Metrics/MethodLength

      def add_errors(errors)
        errors.to_hash.each_pair do |key, value|
          add_error(key, value)
        end
      end

      def add_information(hash)
        @information.merge!(hash)
      end

      def add_execution(step)
        @executions << step
      end
    end
  end
end
