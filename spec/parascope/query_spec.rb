require 'spec_helper'
require 'ostruct'

RSpec.describe Parascope::Query do
  class SpecQuery < Parascope::Query
    defaults default: 'default'

    base_scope { OpenStruct.new }

    query_by :presence_field do |field|
      scope.tap{ scope.presence_field = field }
    end

    query_by value_field: 'exact_value' do
      scope.tap{ scope.value_field = 'value' }
    end

    sift_by sifting_filed: 'sifted' do |sift_value|
      defaults nested_default: 'nested_default'

      base_scope { |scope| scope.tap{ scope.nested_base_value = params.nested_default } }

      query_by :nested_presence_field do |field|
        scope.tap{ scope.nested_presence_field = field }
      end

      query_by :default do |value|
        scope.tap{ scope.value_from_top_defaults = value }
      end

      sift_by :nested_sifting do |nested_sift_value|
        query_by :deep_presence_field do |value|
          scope.tap{ scope.deep_field = [sift_value, nested_sift_value, value].join('-') }
        end
      end
    end
  end

  let(:query)  { SpecQuery.new(params) }
  subject { query.resolved_scope.to_h }

  describe 'querying' do
    context 'when no query passed criteria' do
      let(:params) { {presence_field: ''} }

      it { is_expected.to be_empty }
    end

    context 'when presence_field is present' do
      let(:params) { {presence_field: 'value'} }

      it { is_expected.to match(presence_field: 'value') }
    end

    context "when value field present, but doesn't match" do
      let(:params) { {value_field: 'some_value'} }

      it { is_expected.to be_empty }
    end

    context 'when value field matches params' do
      let(:params) { {value_field: 'exact_value'} }

      it { is_expected.to match(value_field: 'value') }
    end

    context 'when sifting criteria passed' do
      let(:params) { {sifting_filed: 'sifted'} }

      it { is_expected.to match(nested_base_value: 'nested_default', value_from_top_defaults: 'default') }

      context 'with presence field' do
        let(:params) { {sifting_filed: 'sifted', nested_presence_field: 'nested value'} }

        it { is_expected.to include(nested_presence_field: 'nested value') }
      end

      context 'and deep sifting criteria and query field passed' do
        let(:params) { {sifting_filed: 'sifted', nested_sifting: 'nested_sifted', deep_presence_field: 'deep_field'} }

        it { is_expected.to match(
          nested_base_value: 'nested_default',
          value_from_top_defaults: 'default',
          deep_field: 'sifted-nested_sifted-deep_field'
        ) }
      end
    end
  end

  describe 'helpers' do
    describe 'arbitrary readers' do
      let(:user)   { Object.new }
      let(:params) { {} }
      let(:query)  { SpecQuery.new(params, user: user) }

      specify { expect(query.user).to be user }
    end

    describe 'query application order control' do
      let(:klass) do
        Class.new(Parascope::Query) do
          base_scope { OpenStruct.new(foo: 'value') }
          query_by(:foo) { scope.tap{ scope.foo << '-foo' } }
          query_by(:bar, index: -1) { scope.tap{ scope.foo.replace('bar-' + scope.foo) } }
        end
      end

      let(:query) { klass.new(foo: true, bar: true) }

      subject { query.resolved_scope.to_h }

      it { is_expected.to eq(foo: 'bar-value-foo') }
    end

    describe 'brackets delegation' do
      let(:params) { {field: 'value'} }
      let(:query)  { SpecQuery.new(params) }

      specify { expect(query[:field]).to eq 'value' }
    end
  end
end
