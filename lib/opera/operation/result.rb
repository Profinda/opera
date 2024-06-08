# frozen_string_literal: true

module Opera
  module Operation
    class Result
      attr_reader :errors, # Acumulator of errors in validation + steps
                  :exceptions, # Acumulator of exceptions in steps
                  :information, # Temporal object to store related information
                  :executions # Stacktrace or Pipe of the methods evaludated

      attr_accessor :output # Final object returned if success?

      alias to_h output

      def initialize(output: nil, errors: {})
        @errors = errors
        @exceptions = {}
        @information = {}
        @executions = []
        @output = output
      end

      def failure?
        errors.any? || exceptions.any?
      end

      def success?
        !failure?
      end

      def failures
        errors.merge(exceptions)
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

      def add_exception(method, message, classname: nil)
        key = [classname, Array(method).first].compact.join('#')
        @exceptions[key] ||= []
        @exceptions[key].push(message)
      end

      def add_exceptions(exceptions)
        exceptions.each_pair do |key, value|
          add_exception(key, value)
        end
      end

      def add_information(hash)
        @information.merge!(hash)
      end

      def add_execution(step)
        return if config.production_mode?

        @executions << step
      end

      private

      def config
        Config
      end
    end
  end
end
