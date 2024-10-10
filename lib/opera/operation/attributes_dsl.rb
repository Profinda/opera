# frozen_string_literal: true

module Opera
  module Operation
    class AttributesDSL
      attr_accessor :klass, :block_name, :allowed

      def initialize(klass:, block_name:, allowed: [:attr_reader])
        @klass = klass
        @allowed = allowed
        @block_name = block_name
      end

      def attr_reader(*attributes, **options)
        raise NoMethodError, "You cannot use attr_reader inside #{klass.name}##{block_name}" unless allowed.include?(:attr_reader)

        attributes.each do |attribute|
          klass.check_method_availability!(attribute)

          method = block_name
          klass.define_method(attribute) do
            value = if send(method).key?(attribute)
              send(method)[attribute]
            elsif options[:default]
              instance_exec(&options[:default])
            end

            if send(method).frozen?
              send(method)[attribute] || value
            else
              send(method)[attribute] ||= value
            end
          end
        end
      end

      def attr_writer(*attributes, **options)
        raise NoMethodError, "You cannot use attr_writer inside #{klass.name}##{block_name}" unless allowed.include?(:attr_accessor)

        attributes.each do |attribute|
          klass.check_method_availability!("#{attribute}=")
          method = block_name
          klass.define_method("#{attribute}=") do |value|
            send(method)[attribute] = value
          end
        end
      end

      def attr_accessor(*attributes, **options)
        raise NoMethodError, "You cannot use attr_accessor inside #{klass.name}##{block_name}" unless allowed.include?(:attr_accessor)

        attr_reader(*attributes, **options)
        attr_writer(*attributes)
      end
    end
  end
end
