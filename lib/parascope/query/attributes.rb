# frozen_string_literal: true

module Parascope
  class Query
    module Attributes
      module ClassMethods
        def inherited(query_class)
          query_class.const_set(:AttributeMethods, Module.new)
          query_class.send(:include, query_class::AttributeMethods)
          query_class.attributes_list.replace(attributes_list.dup)
          super
        end

        def attribute_methods
          const_get(:AttributeMethods)
        end

        def attributes(*attrs)
          attributes_list.concat(attrs)

          attrs.each do |name|
            attribute_methods.send(:define_method, name) { @attributes[name] }
          end
        end

        def attributes_list
          @attributes_list ||= []
        end
      end

      def self.included(target)
        target.extend(ClassMethods)
      end

      def initialize(**attrs)
        attributes = attrs.dup
        attributes.delete(:params)
        assert_valid_attributes!(attributes)
        @attributes = attributes
      end

      private

      def assert_valid_attributes!(attrs)
        unknown_attrs = attrs.keys - self.class.attributes_list

        raise(ArgumentError, "Unknown attributes #{unknown_attrs.inspect}") if unknown_attrs.any?
      end
    end
  end
end
