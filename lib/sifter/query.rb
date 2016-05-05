require 'hashie/mash'

class Sifter::Query
  extend Forwardable
  extend Sifter::Query::ApiMethods

  UndefinedScopeError = Class.new(StandardError)

  attr_reader :params
  def_delegator :params, :[]

  def self.inherited(subclass)
    subclass.query_blocks.replace query_blocks.dup
    subclass.base_scope(&base_scope)
    subclass.defaults defaults
  end

  def initialize(params, scope: nil)
    @params = Hashie::Mash.new(params.merge(self.class.defaults))
    @scope  = scope unless scope.nil?
  end

  def scope
    @scope ||= base_scope
  end

  def base_scope
    self.class.ancestors
      .select{ |klass| klass < Sifter::Query }
      .reverse
      .map(&:base_scope)
      .compact
      .reduce(nil){ |scope, block| instance_exec(scope, &block) }
      .tap do |scope|
        if scope.nil?
          fail UndefinedScopeError, "Failed to build scope. Have you missed base_scope definition?"
        end
      end
  end

  def resolved_scope(params = nil)
    return siftered_instance.resolved_scope! if params.nil?

    clone_with_params(params).resolved_scope
  end

  protected

  attr_writer :scope, :params
  attr_accessor :block

  def siftered_instance
    block = self.class.sifter_blocks.find{ |block| block.fits?(params) }

    block ? siftered_instance_for(block) : self
  end

  def resolved_scope!
    self.class.query_blocks.reduce(scope) do |scope, block|
      clone_with(scope, block).apply_block!.scope
    end
  end

  def apply_block!
    if block && block.fits?(params)
      self.scope = instance_exec(*block.values_for(params), &block.block)
    end
    self
  end

  private

  def clone_with(scope, block)
    clone.tap do |query|
      query.scope = scope
      query.block = block
    end
  end

  def clone_with_params(other_params)
    clone.tap do |query|
      query.params = params.merge(other_params)
    end
  end

  def siftered_instance_for(block)
    klass = Class.new(self.class)
    klass.instance_exec(*block.values_for(params), &block.block)
    klass.new(params).siftered_instance
  end
end
