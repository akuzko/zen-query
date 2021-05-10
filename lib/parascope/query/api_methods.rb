# frozen_string_literal: true

module Parascope
  class Query
    module ApiMethods
      def base_scope(&block)
        return @base_scope unless block_given?

        @base_scope = block
      end
      alias base_dataset base_scope

      def defaults(params = nil, &block) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        return @defaults if params.nil? && !block_given?

        if block_given? && !params.nil?
          defaults(params)
          defaults(&block)
        elsif !block_given? && params.is_a?(Proc)
          @defaults = params
        elsif !block_given?
          defaults { params }
        elsif @defaults.nil?
          @defaults = block
        else
          defaultz = @defaults
          @defaults = -> { block.call.merge(defaultz.call) }
        end
      end

      def fetch_defaults
        defaults.nil? ? {} : defaults.call
      end

      def sift_by(*presence_fields, **value_fields, &block)
        sift_blocks.push Query::ApiBlock.new(
          presence_fields: presence_fields,
          value_fields: value_fields,
          block: block
        )
      end

      def query_by(*presence_fields, **value_fields, &block)
        query_blocks.push Query::ApiBlock.new(
          presence_fields: presence_fields,
          value_fields: value_fields,
          block: block
        )
      end

      alias sifter sift_by
      alias query query_by

      def sift_by!(*presence_fields, &block)
        sift_blocks.push Query::ApiBlock.new(
          presence_fields: presence_fields,
          value_fields: {},
          block: block,
          force: true
        )
      end

      def query_by!(*presence_fields, &block)
        query_blocks.push Query::ApiBlock.new(
          presence_fields: presence_fields,
          value_fields: {},
          block: block,
          force: true
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
