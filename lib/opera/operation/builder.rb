# frozen_string_literal: true

module Opera
  module Operation
    module Builder
      INSTRUCTIONS = %I[validate transaction step success finish_if operation operations within always].freeze
      INNER_INSTRUCTIONS = (INSTRUCTIONS - %I[always]).freeze

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def instructions
          @instructions ||= []
        end

        INNER_INSTRUCTIONS.each do |instruction|
          define_method instruction do |method = nil, &blk|
            if instructions.any? { |i| i[:kind] == :always }
              raise ArgumentError,
                    "`#{instruction}` cannot appear after `always`. " \
                    'All `always` steps must be at the end of the operation.'
            end

            check_method_availability!(method) if method
            instructions.concat(InnerBuilder.new.send(instruction, method, &blk))
          end
        end

        define_method :always do |method = nil, &_blk|
          check_method_availability!(method) if method
          instructions << { kind: :always, method: method }
        end
      end

      class InnerBuilder
        attr_reader :instructions

        def initialize(&block)
          @instructions = []
          instance_eval(&block) if block_given?
        end

        INNER_INSTRUCTIONS.each do |instruction|
          define_method instruction do |method = nil, &blk|
            instructions << if !blk.nil?
                              {
                                kind: instruction,
                                label: method,
                                instructions: InnerBuilder.new(&blk).instructions
                              }
                            else
                              {
                                kind: instruction,
                                method: method
                              }
                            end
          end
        end

        define_method :always do |_method = nil, &_blk|
          raise ArgumentError,
                '`always` cannot be used inside a block (transaction, within, success, validate). ' \
                'Place `always` steps at the top level of the operation, after all other instructions.'
        end
      end
    end
  end
end
