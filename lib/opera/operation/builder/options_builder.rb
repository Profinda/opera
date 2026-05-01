# frozen_string_literal: true

module Opera
  module Operation
    module Builder
      # Parses keyword options passed to a Builder instruction (`step`,
      # `operation`, `transaction`, etc.) into a normalized hash that is merged
      # into the instruction entry.
      #
      # Currently understands `:if` and `:unless`. New options can be added by
      # extending ALLOWED_OPTIONS and the build logic.
      class OptionsBuilder
        ALLOWED_OPTIONS = %i[if unless].freeze

        def self.build(opts)
          return {} if opts.empty?

          unknown = opts.keys - ALLOWED_OPTIONS
          raise ArgumentError, "Unknown option(s): #{unknown.inspect}. Allowed: #{ALLOWED_OPTIONS}" if unknown.any?

          { predicate: build_predicate(opts) }.compact
        end

        # Translates `:if` / `:unless` (Symbol or Proc) into a single Proc that
        # returns true when the step should run. Returns nil when neither is
        # given. Raises if both are given.
        def self.build_predicate(opts)
          return nil unless opts[:if] || opts[:unless]
          raise ArgumentError, 'Cannot use both :if and :unless on the same step' if opts[:if] && opts[:unless]

          cond = opts[:if] || opts[:unless]
          body = cond.is_a?(Symbol) ? proc { send(cond) } : cond
          opts.key?(:if) ? body : proc { !instance_exec(&body) }
        end
      end
    end
  end
end
