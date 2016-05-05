class Sifter::Query
  module ApiMethods
    def base_scope(&block)
      return @base_scope unless block_given?

      @base_scope = block
    end

    def defaults(params = nil)
      @defaults ||= {}

      return @defaults if params.nil?

      @defaults = @defaults.merge(params)
    end

    def sifter_by(*presence_fields, **value_fields, &block)
      sifter_blocks.push ApiBlock.new(presence_fields, value_fields, block)
    end

    def query_by(*presence_fields, **value_fields, &block)
      query_blocks.push ApiBlock.new(presence_fields, value_fields, block)
    end

    def sifter_blocks
      @sifter_blocks ||= []
    end

    def query_blocks
      @query_blocks ||= []
    end
  end
end
