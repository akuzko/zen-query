module Parascope
  class Query::ApiBlock
    attr_reader :presence_fields, :value_fields, :block, :index

    def initialize(presence_fields:, value_fields:, block:, index: 0)
      @presence_fields, @value_fields, @block, @index =
        presence_fields, value_fields, block, index
    end

    def fits?(params)
      (presence_fields.size == 0 && value_fields.size == 0) ||
        values_for(params).all?{ |value| present?(value) }
    end

    def values_for(params)
      params.values_at(*presence_fields) + valued_values_for(params)
    end

    def present?(value)
      value.respond_to?(:empty?) ? !value.empty? : !!value
    end

    private

    def valued_values_for(params)
      value_fields.map do |field, required_value|
        params[field] == required_value && required_value
      end
    end
  end
end
