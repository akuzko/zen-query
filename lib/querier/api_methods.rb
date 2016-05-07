module Querier::ApiMethods
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
    sifter_blocks.push Querier::ApiBlock.new(presence_fields, value_fields, block)
  end

  def query_by(*presence_fields, **value_fields, &block)
    query_blocks.push Querier::ApiBlock.new(presence_fields, value_fields, block)
  end

  def sifter_blocks
    @sifter_blocks ||= []
  end

  def query_blocks
    @query_blocks ||= []
  end
end
