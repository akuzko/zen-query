# frozen_string_literal: true

module Parascope
  class Query
    module ApiMethods
      def alias_subject_name(name)
        @subject_name = name

        define_singleton_method(name) { |&block| subject(&block) }

        alias_method(name, :subject)
      end

      def subject_name
        @subject_name || :subject
      end

      def raise_on_guard_violation(value)
        @raise_on_guard_violation = !!value
      end

      def raise_on_guard_violation?
        @raise_on_guard_violation
      end

      def subject(&block)
        return @subject_block unless block_given?

        @subject_block = block
      end

      def defaults(&block)
        return @defaults_block unless block_given?

        @defaults_block = block
      end

      def fetch_defaults
        ancestors
          .select { |mod| mod.respond_to?(:defaults) }
          .map(&:defaults)
          .compact
          .reduce({}) { |result, block| result.merge!(block.call) }
      end

      def sift_by(*presence_fields, **value_fields, &block)
        sift_blocks.push(
          Query::ApiBlock.new(
            presence_fields: presence_fields,
            value_fields: value_fields,
            block: block
          )
        )
      end

      def query_by(*presence_fields, **value_fields, &block)
        query_blocks.push(
          Query::ApiBlock.new(
            presence_fields: presence_fields,
            value_fields: value_fields,
            block: block
          )
        )
      end

      alias sifter sift_by
      alias query query_by

      def sift_by!(*presence_fields, &block)
        sift_blocks.push(
          Query::ApiBlock.new(
            presence_fields: presence_fields,
            value_fields: {},
            block: block,
            force: true
          )
        )
      end

      def query_by!(*presence_fields, &block)
        query_blocks.push(
          Query::ApiBlock.new(
            presence_fields: presence_fields,
            value_fields: {},
            block: block,
            force: true
          )
        )
      end

      alias sifter! sift_by!
      alias query! query_by!

      def guard(message = nil, &block)
        guard_blocks.push([message, block])
      end

      def sift_blocks
        @sift_blocks ||= []
      end

      def query_blocks
        @query_blocks ||= []
      end

      def guard_blocks
        @guard_blocks ||= []
      end

      def sorted_query_blocks
        query_blocks.sort do |a, b|
          if a.index == b.index
            query_blocks.index(a) <=> query_blocks.index(b)
          else
            a.index <=> b.index
          end
        end
      end
    end
  end
end
