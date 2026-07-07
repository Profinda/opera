# frozen_string_literal: true

module Opera
  module Operation
    module Builder
      class OptionsBuilder
        ALLOWED_OPTIONS = %i[if unless].freeze

        def self.build(opts)
          return {} if opts.empty?

          unknown = opts.keys - ALLOWED_OPTIONS
          raise ArgumentError, "Unknown option(s): #{unknown.inspect}. Allowed: #{ALLOWED_OPTIONS}" if unknown.any?

          { predicate: build_predicate(opts) }.compact
        end

        def self.build_predicate(opts)
          return nil unless opts[:if] || opts[:unless]
          raise ArgumentError, 'Cannot use :if and :unless together' if opts[:if] && opts[:unless]

          cond = opts[:if] || opts[:unless]
          condition_proc = cond.is_a?(Symbol) ? proc { send(cond) } : cond
          opts.key?(:if) ? condition_proc : proc { !instance_exec(&condition_proc) }
        end
      end
    end
  end
end
