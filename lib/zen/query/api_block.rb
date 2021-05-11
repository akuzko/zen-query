# frozen_string_literal: true

module Zen
  class Query
    class ApiBlock
      OPTION_KEYS = %i[index if unless].freeze
      private_constant :OPTION_KEYS

      attr_reader :presence_fields, :value_fields, :block, :force, :options

      def initialize(presence_fields:, value_fields:, block:, force: false)
        @options = extract_options!(value_fields)

        @presence_fields = presence_fields
        @value_fields = value_fields
        @block = block
        @force = force
      end

      def fits?(query)
        return false unless conditions_met_by?(query)
        return true if force

        (presence_fields.empty? && value_fields.empty?) ||
          values_for(query.params).all? { |value| present?(value) }
      end

      def values_for(params)
        params.values_at(*presence_fields) + valued_values_for(params)
      end

      def present?(value)
        value.respond_to?(:empty?) ? !value.empty? : !!value
      end

      def index
        case options[:index]
        when :first  then -Float::INFINITY
        when :last   then Float::INFINITY
        when Numeric then options[:index]
        else 0
        end
      end

      private

      def extract_options!(fields)
        fields.keys.each_with_object({}) do |key, options|
          options[key] = fields.delete(key) if OPTION_KEYS.include?(key)
        end
      end

      def valued_values_for(params)
        value_fields.map do |field, required_value|
          params[field] == required_value && required_value
        end
      end

      def conditions_met_by?(query)
        condition_met?(query, :if) && condition_met?(query, :unless)
      end

      def condition_met?(query, key)
        return true unless options.key?(key)

        condition = options[key]

        value =
          case condition
          when String, Symbol then query.send(condition)
          when Proc then query.instance_exec(&condition)
          else condition
          end

        key == :if ? value : !value
      end
    end
  end
end
