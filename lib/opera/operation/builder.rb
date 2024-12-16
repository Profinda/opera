# frozen_string_literal: true

module Opera
  module Operation
    module Builder
      INSTRUCTIONS = %I[validate transaction benchmark step success finish_if operation operations].freeze

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def instructions
          @instructions ||= []
        end

        INSTRUCTIONS.each do |instruction|
          define_method instruction do |method = nil, &blk|
            self.check_method_availability!(method) if method
            instructions.concat(InnerBuilder.new.send(instruction, method, &blk))
          end
        end
      end

      class InnerBuilder
        attr_reader :instructions

        def initialize(&block)
          @instructions = []
          instance_eval(&block) if block_given?
        end

        INSTRUCTIONS.each do |instruction|
          define_method instruction do |method = nil, &blk|
            instructions << if !blk.nil?
                              {
                                kind: instruction,
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
      end
    end
  end
end
