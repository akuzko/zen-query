# frozen_string_literal: true

require_relative "query/api_block"
require_relative "query/api_methods"
require_relative "query/attributes"

module Zen
  class Query # rubocop:disable Metrics/ClassLength
    UndefinedSubjectError = Class.new(StandardError)
    GuardViolationError = Class.new(ArgumentError)

    extend ApiMethods
    include Attributes

    raise_on_guard_violation(true)

    attr_reader :params, :violation

    def self.inherited(subclass) # rubocop:disable Metrics/AbcSize
      subclass.raise_on_guard_violation(raise_on_guard_violation?)
      subclass.query_blocks.replace(query_blocks.dup)
      subclass.sift_blocks.replace(sift_blocks.dup)
      subclass.guard_blocks.replace(guard_blocks.dup)
      subclass.subject(&subject)
      subclass.defaults(&defaults) unless defaults.nil?
      super
    end

    def initialize(params: {}, **attrs)
      @params  = klass.fetch_defaults.merge(params)
      @subject = attrs.delete(self.class.subject_name)
      @base_params = @params
      super
    end

    def subject
      @subject ||= base_subject
    end

    def base_subject
      subject =
        klass
          .ancestors
          .select { |mod| mod.respond_to?(:subject) }
          .map(&:subject)
          .compact
          .first
          &.call

      raise UndefinedSubjectError, "failed to build subject. Have you missed subject definition?" if subject.nil?

      subject
    end

    def resolve(*args)
      @violation = nil
      arg_params = args.pop if args.last.is_a?(Hash)
      return sifted_instance.resolve! if arg_params.nil? && args.empty?

      clone_with_params(trues(args).merge(arg_params || {})).resolve
    rescue GuardViolationError => e
      @violation = e.message
      raise if self.class.raise_on_guard_violation?
    end

    def klass
      sifted? ? singleton_class : self.class
    end

    protected

    attr_writer :subject, :params
    attr_accessor :block
    attr_reader :attrs

    def sifted_instance
      blocks = klass.sift_blocks.select { |block| block.fits?(self) }

      blocks.empty? ? self : sifted_instance_for(blocks)
    end

    def resolve!
      guard_all
      klass.sorted_query_blocks.reduce(subject) do |subject, block|
        clone_with_subject(subject, block).apply_block!.subject
      end
    end

    def apply_block!
      if block&.fits?(self)
        subject  = instance_exec(*block.values_for(params), &block.block)
        @subject = subject unless subject.nil?
      end
      self
    end

    def sifted!(query, blocks) # rubocop:disable Metrics/AbcSize
      singleton_class.query_blocks.replace(query.klass.query_blocks.dup)
      singleton_class.guard_blocks.replace(query.klass.guard_blocks.dup)
      singleton_class.subject(&query.klass.subject)
      blocks.each do |block|
        singleton_class.instance_exec(*block.values_for(params), &block.block)
      end
      params.replace(singleton_class.fetch_defaults.merge(params))
      @sifted = true
    end

    def sifted?
      !!@sifted
    end

    def clone_with_subject(subject, block = nil)
      clone.tap do |query|
        query.subject = subject
        query.block = block
      end
    end

    def clone_with_params(other_params)
      dup.tap do |query|
        query.params = @base_params.merge(other_params)
        query.remove_instance_variable("@sifted") if query.instance_variable_defined?("@sifted")
        query.remove_instance_variable("@subject") if query.instance_variable_defined?("@subject")
      end
    end

    def clone_sifted_with(blocks)
      dup.tap do |query|
        query.sifted!(self, blocks)
      end
    end

    private

    def guard_all
      klass.guard_blocks.each { |message, block| guard(message, &block) }
    end

    def guard(message = nil, &block)
      return if instance_exec(&block)

      violation = message || "guard block violated on #{block.source_location.join(':')}"

      raise GuardViolationError, violation
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
