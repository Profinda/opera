# frozen_string_literal: true

module Opera
  module Operation
    module Builder
      INSTRUCTIONS = %I[validate transaction step success finish_if operation operations within always].freeze
      INNER_INSTRUCTIONS = (INSTRUCTIONS - %I[always]).freeze
      OUTPUT_INSTRUCTIONS = %I[validate operation operations].freeze

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
            define_output_reader(method) if method && OUTPUT_INSTRUCTIONS.include?(instruction)
            instructions.concat(InnerBuilder.new.send(instruction, method, **opts, &blk))
          end
        end

        def always(method)
          check_method_availability!(method)
          instructions << { kind: :always, method: method }
        end

        def define_output_reader(method)
          reader = :"#{method}_output"
          return unless instance_methods(false).none?(reader)

          context { attr_reader(reader) }
        end
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
            instructions << entry.merge(OptionsBuilder.build(opts))
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
