module Parascope
  module Query::ApiMethods
    def base_scope(&block)
      return @base_scope unless block_given?

      @base_scope = block
    end

    def defaults(params = nil)
      @defaults ||= {}

      return @defaults if params.nil?

      @defaults = @defaults.merge(params)
    end

    def sift_by(*presence_fields, **value_fields, &block)
      sifter_blocks.push Query::ApiBlock.new(presence_fields, value_fields, block)
    end

    def query_by(*presence_fields, index: 0, **value_fields, &block)
      query_blocks.push Query::ApiBlock.new(presence_fields, value_fields, block, index)
    end

    def guard(&block)
      guard_blocks.push block
    end

    def sifter_blocks
      @sifter_blocks ||= []
    end

    def query_blocks
      @query_blocks ||= []
    end

    def guard_blocks
      @guard_blocks ||= []
    end
  end
end
