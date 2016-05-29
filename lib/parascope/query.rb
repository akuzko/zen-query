require "hashie/mash"

module Parascope
  class Query
    autoload :ApiMethods, "parascope/query/api_methods"
    autoload :ApiBlock, "parascope/query/api_block"

    extend Forwardable
    extend ApiMethods

    UndefinedScopeError = Class.new(StandardError)
    GuardViolationError = Class.new(ArgumentError)
    # for backward-compatability
    UnpermittedError = GuardViolationError

    attr_reader :params
    def_delegator :params, :[]

    def self.inherited(subclass)
      subclass.query_blocks.replace query_blocks.dup
      subclass.sift_blocks.replace sift_blocks.dup
      subclass.guard_blocks.replace guard_blocks.dup
      subclass.base_scope(&base_scope)
      subclass.defaults defaults
    end

    def initialize(params, scope: nil, **attrs)
      @params = Hashie::Mash.new(klass.defaults).merge(params || {})
      @scope  = scope unless scope.nil?
      @attrs  = attrs.freeze
      @base_params = @params
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
        fail UndefinedScopeError, "failed to build scope. Have you missed base_scope definition?"
      end

      scope
    end

    def resolved_scope(*args)
      arg_params = args.pop if args.last.is_a?(Hash)
      return sifted_instance.resolved_scope! if arg_params.nil? && args.empty?

      clone_with_params(trues(args).merge(arg_params || {})).resolved_scope
    end

    def klass
      sifted? ? singleton_class : self.class
    end

    protected

    attr_writer :scope, :params
    attr_accessor :block
    attr_reader :attrs

    def sifted_instance
      blocks = klass.sift_blocks.select{ |block| block.fits?(self) }

      blocks.size > 0 ? sifted_instance_for(blocks) : self
    end

    def resolved_scope!
      guard_all
      klass.query_blocks.sort{ |a, b| a.index <=> b.index }.reduce(scope) do |scope, block|
        clone_with_scope(scope, block).apply_block!.scope
      end
    end

    def apply_block!
      if block && block.fits?(self)
        scope  = instance_exec(*block.values_for(params), &block.block)
        @scope = scope unless scope.nil?
      end
      self
    end

    def sifted!(query, blocks)
      @attrs = query.attrs
      define_attr_readers
      singleton_class.query_blocks.replace query.klass.query_blocks.dup
      singleton_class.guard_blocks.replace query.klass.guard_blocks.dup
      singleton_class.base_scope(&query.klass.base_scope)
      blocks.each do |block|
        singleton_class.instance_exec(*block.values_for(params), &block.block)
      end
      params.replace(singleton_class.defaults.merge(params))
      @sifted = true
    end

    def sifted?
      !!@sifted
    end

    def clone_with_scope(scope, block = nil)
      clone.tap do |query|
        query.scope = scope
        query.block = block
      end
    end

    def clone_with_params(other_params)
      dup.tap do |query|
        query.params = @base_params.merge(other_params)
        query.remove_instance_variable('@sifted') if query.instance_variable_defined?('@sifted')
        query.remove_instance_variable('@scope') if query.instance_variable_defined?('@scope')
        query.define_attr_readers
      end
    end

    def clone_sifted_with(blocks)
      dup.tap do |query|
        query.sifted!(self, blocks)
      end
    end

    def define_attr_readers
      @attrs.each do |name, value|
        define_singleton_method(name){ value }
      end
    end

    private

    def guard_all
      klass.guard_blocks.each{ |block| guard(&block) }
    end

    def guard(&block)
      unless instance_exec(&block)
        fail GuardViolationError, "guard block violated on #{block.source_location.join(':')}"
      end
    end

    def sifted_instance_for(blocks)
      clone_sifted_with(blocks).sifted_instance
    end

    def trues(keys)
      keys.each_with_object({}) do |key, hash|
        hash[key] = true
      end
    end
  end
end
