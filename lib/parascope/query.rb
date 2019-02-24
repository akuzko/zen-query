require "hashie/mash"

module Parascope
  class Query
    autoload :ApiMethods, "parascope/query/api_methods"
    autoload :ApiBlock, "parascope/query/api_block"

    extend ApiMethods

    attr_reader :params, :violation

    def self.inherited(subclass)
      subclass.raise_on_guard_violation raise_on_guard_violation?
      subclass.query_blocks.replace query_blocks.dup
      subclass.sift_blocks.replace sift_blocks.dup
      subclass.guard_blocks.replace guard_blocks.dup
      subclass.base_scope(&base_scope)
      subclass.defaults defaults
    end

    def self.build(**attrs)
      new({}, **attrs)
    end

    def self.raise_on_guard_violation(value)
      @raise_on_guard_violation = !!value
    end

    def self.raise_on_guard_violation?
      @raise_on_guard_violation
    end

    def initialize(params, scope: nil, dataset: nil, **attrs)
      @params = Hashie::Mash.new(klass.defaults).merge(params || {})
      @scope  = scope || dataset unless scope.nil? && dataset.nil?
      @attrs  = attrs.freeze
      @base_params = @params
      define_attr_readers
    end

    def scope
      @scope ||= base_scope
    end
    alias_method :dataset, :scope

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
    alias_method :base_dataset, :base_scope

    def resolved_scope(*args)
      @violation = nil
      arg_params = args.pop if args.last.is_a?(Hash)
      return sifted_instance.resolved_scope! if arg_params.nil? && args.empty?

      clone_with_params(trues(args).merge(arg_params || {})).resolved_scope
    rescue GuardViolationError => error
      @violation = error.message
      raise if self.class.raise_on_guard_violation?
    end
    alias_method :resolved_dataset, :resolved_scope
    alias_method :resolve, :resolved_scope

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
      klass.sorted_query_blocks.reduce(scope) do |scope, block|
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
      klass.guard_blocks.each{ |message, block| guard(message, &block) }
    end

    def guard(message = nil, &block)
      return if instance_exec(&block)

      violation = message || "guard block violated on #{block.source_location.join(':')}"

      fail GuardViolationError, violation
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
