# frozen_string_literal: true

module Opera
  module Operation
    module Builder
      INSTRUCTIONS = %I[validate transaction step success finish_if operation operations within always].freeze
      INNER_INSTRUCTIONS = (INSTRUCTIONS - %I[always]).freeze
      CONDITIONABLE_INSTRUCTIONS = %I[step operation operations].freeze

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def instructions
          @instructions ||= []
        end

        INNER_INSTRUCTIONS.each do |instruction|
          define_method instruction do |method = nil, **opts, &blk|
            if instructions.any? { |i| i[:kind] == :always }
              raise ArgumentError,
                    "`#{instruction}` cannot appear after `always`. " \
                    'All `always` steps must be at the end of the operation.'
            end

            check_method_availability!(method) if method
            instructions.concat(InnerBuilder.new.send(instruction, method, **opts, &blk))
          end
        end

        def always(method)
          check_method_availability!(method)
          instructions << { kind: :always, method: method }
        end
      end

      # Translates `:if` / `:unless` (Symbol or Proc) into a single Proc that
      # returns true when the step should run. Returns nil when no condition is
      # configured. Raises if both options are given, an unknown option is
      # given, or the instruction does not support conditions.
      def self.build_predicate(instruction, opts)
        return nil if opts.empty?

        unknown = opts.keys - %i[if unless]
        raise ArgumentError, "Unknown option(s): #{unknown.inspect}. Allowed: :if, :unless" if unknown.any?

        unless CONDITIONABLE_INSTRUCTIONS.include?(instruction)
          raise ArgumentError, ":if/:unless are not supported on `#{instruction}`"
        end

        raise ArgumentError, 'Cannot use both :if and :unless on the same step' if opts[:if] && opts[:unless]

        cond = opts[:if] || opts[:unless]
        body = cond.is_a?(Symbol) ? proc { send(cond) } : cond
        opts.key?(:if) ? body : proc { !instance_exec(&body) }
      end

      class InnerBuilder
        attr_reader :instructions

        def initialize(&block)
          @instructions = []
          instance_eval(&block) if block_given?
        end

        INNER_INSTRUCTIONS.each do |instruction|
          define_method instruction do |method = nil, **opts, &blk|
            entry = if blk
                      { kind: instruction, label: method, instructions: InnerBuilder.new(&blk).instructions }
                    else
                      { kind: instruction, method: method }
                    end
            if (predicate = Builder.build_predicate(instruction, opts))
              entry[:predicate] = predicate
            end
            instructions << entry
          end
        end

        def always(_method)
          raise ArgumentError,
                '`always` cannot be used inside a block (transaction, within, success, validate). ' \
                'Place `always` steps at the top level of the operation, after all other instructions.'
        end
      end
    end
  end
end
