require "hashie/mash"

module Parascope
  class Query
    autoload :ApiMethods, "parascope/query/api_methods"
    autoload :ApiBlock, "parascope/query/api_block"

    extend Forwardable
    extend ApiMethods

    UndefinedScopeError = Class.new(StandardError)

    attr_reader :params
    def_delegator :params, :[]

    def self.inherited(subclass)
      subclass.query_blocks.replace query_blocks.dup
      subclass.base_scope(&base_scope)
      subclass.defaults defaults
    end

    def initialize(params, scope: nil, **attrs)
      @params = Hashie::Mash.new(klass.defaults).merge(params || {})
      @scope  = scope unless scope.nil?
      @attrs  = attrs
      define_attr_readers
    end

    def scope
      @scope ||= base_scope
    end

    def base_scope
      scope = klass.ancestors
        .select{ |klass| klass < Query }
        .reverse
        .map(&:base_scope)
        .compact
        .reduce(nil){ |scope, block| instance_exec(scope, &block) }

      if scope.nil?
        fail UndefinedScopeError, "Failed to build scope. Have you missed base_scope definition?"
      end

      scope
    end

    def resolved_scope(params = nil)
      return siftered_instance.resolved_scope! if params.nil?

      clone_with_params(params).resolved_scope
    end

    def klass
      siftered? ? singleton_class : self.class
    end

    protected

    attr_writer :scope, :params
    attr_accessor :block
    attr_reader :attrs

    def siftered_instance
      block = klass.sifter_blocks.find{ |block| block.fits?(params) }

      block ? siftered_instance_for(block) : self
    end

    def resolved_scope!
      klass.query_blocks.sort{ |a, b| a.index <=> b.index }.reduce(scope) do |scope, block|
        clone_with_scope(scope, block).apply_block!.scope
      end
    end

    def apply_block!
      if block && block.fits?(params)
        scope  = instance_exec(*block.values_for(params), &block.block)
        @scope = scope unless scope.nil?
      end
      self
    end

    def siftered!(block, query)
      @attrs = query.attrs
      define_attr_readers
      singleton_class.query_blocks.replace query.klass.query_blocks.dup
      singleton_class.base_scope(&query.klass.base_scope)
      singleton_class.instance_exec(*block.values_for(params), &block.block)
      params.replace(singleton_class.defaults.merge(params))
      @siftered = true
    end

    private

    def clone_with_scope(scope, block)
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

    def clone_with_sifter(block)
      dup.tap do |query|
        query.siftered!(block, self)
      end
    end

    def siftered?
      !!@siftered
    end

    def siftered_instance_for(block)
      clone_with_sifter(block).siftered_instance
    end

    def define_attr_readers
      @attrs.each do |name, value|
        define_singleton_method(name){ value }
      end
    end
  end
end
