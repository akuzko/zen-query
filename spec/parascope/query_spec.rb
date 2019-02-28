require 'spec_helper'
require 'ostruct'

RSpec.describe Parascope::Query do
  def self.feature(&block)
    let(:feature_block) { block }
  end

  def self.params(hash)
    let(:params) { hash }
  end

  let(:query)  { query_klass.new(params) }
  let(:params) { {} }
  let(:feature_block) { proc{} }
  let(:query_klass) do
    Class.new(Parascope::Query, &feature_block).tap do |klass|
      klass.base_scope { OpenStruct.new } if klass.base_scope.nil?
    end
  end

  subject(:resolved_scope) { query.resolved_scope.to_h }

  describe 'querying' do
    describe 'presence field' do
      feature do
        query_by :foo do |foo|
          scope.tap{ scope.foo = foo }
        end
      end

      context 'when criteria not passed' do
        params foo: ''

        it { is_expected.to be_empty }
      end

      context 'when presence field is present' do
        params foo: 'foo'

        it { is_expected.to match(foo: 'foo') }
      end
    end

    describe 'value field' do
      feature do
        query_by foo: 'exact_value' do
          scope.tap{ scope.value_field = 'value' }
        end
      end

      context "when value field present, but doesn't match" do
        params foo: 'some_value'

        it { is_expected.to be_empty }
      end

      context 'when value field matches params' do
        params foo: 'exact_value'

        it { is_expected.to match(value_field: 'value') }
      end
    end

    describe 'force query' do
      feature do
        query_by!(:foo) do |foo|
          scope.tap{ scope.foo = foo }
        end
      end

      context 'when param is not present' do
        params foo: ''

        it 'applies query anyway' do
          expect(resolved_scope).to match(foo: '')
        end
      end
    end

    describe 'conditionals' do
      describe ':if option' do
        feature do
          query(if: :if_condition?) { scope.tap{ scope.if_condition_passed = true } }

          def if_condition?
            !!params.if_condition
          end
        end

        params if_condition: true

        it { is_expected.to match(if_condition_passed: true) }
      end

      describe ':unless option' do
        feature do
          query(unless: :unless_condition?) { scope.tap{ scope.unless_condition_passed = true } }

          def unless_condition?
            params.unless_condition.nil?
          end
        end

        params unless_condition: true

        it { is_expected.to match(unless_condition_passed: true) }
      end

      describe 'both :if and :unless options' do
        feature do
          query(if: :if_condition?, unless: :unless_condition?) { scope.tap{ scope.both_conditions_passed = true } }

          def if_condition?
            !!params.if_condition
          end

          def unless_condition?
            params.unless_condition.nil?
          end
        end

        context 'when only :if condition passes' do
          params if_condition: true

          it { is_expected.to be_empty }
        end

        context 'when only :unless condition passes' do
          params unless_condition: true

          it { is_expected.to be_empty }
        end

        context 'both conditions passed' do
          params if_condition: true, unless_condition: true

          it { is_expected.to match(both_conditions_passed: true) }
        end
      end
    end

    describe 'sifting' do
      feature do
        sift_by foo: 'foo' do
          query { scope.tap{ scope.sifted = true } }
        end
      end

      context 'when sifter criteria not passed' do
        params foo: 'bar'

        it { is_expected.to be_empty }
      end

      context 'when sifter criteria passed' do
        params foo: 'foo'

        it { is_expected.to match(sifted: true) }
      end

      describe 'multiple sifters' do
        feature do
          sift_by :foo do |value|
            query { scope.tap{ scope.foo_sift = value } }
          end

          sift_by :bar do |value|
            query { scope.tap{ scope.bar_sift = value } }
          end
        end

        context 'when all sifter criteria passed' do
          params foo: 'foo', bar: 'bar'

          it { is_expected.to match(foo_sift: 'foo', bar_sift: 'bar') }
        end
      end

      describe 'nested sifting' do
        feature do
          sift_by foo: 'foo' do
            query { scope.tap{ scope.foo_sift = true } }

            sift_by bar: 'bar' do
              query { scope.tap{ scope.bar_sift = true } }
            end
          end
        end

        context 'when only nested criteria passed' do
          params bar: 'bar'

          it { is_expected.to be_empty }
        end

        context 'when both criterias passed' do
          params foo: 'foo', bar: 'bar'

          it { is_expected.to match(foo_sift: true, bar_sift: true) }
        end
      end

      describe 'cross-sifting' do
        feature do
          sifter :foo do
            query { scope.tap{ scope.foo_sift = bar_scope.bar_sift } }
          end

          sifter :bar do |value|
            query { scope.tap{ scope.bar_sift = value } }
          end

          def bar_scope
            resolved_scope(bar: 'from bar')
          end
        end

        subject { query_klass.build.resolved_scope(:foo).to_h }

        it { is_expected.to match(foo_sift: 'from bar') }
      end

      describe 'force sifting' do
        feature do
          sift_by! :foo do |foo|
            query { scope.tap{ scope.foo = foo } }
          end
        end

        context 'when param is not present' do
          params foo: ''

          it 'applies sifter anyway' do
            expect(resolved_scope).to match(foo: '')
          end
        end
      end
    end

    describe 'defaults' do
      feature do
        defaults foo: 'foo'

        query_by(:foo) { |value| scope.tap{ scope.foo = value } }
      end

      it { is_expected.to match(foo: 'foo') }

      context 'when key is overriden' do
        params foo: 'bar'

        it { is_expected.to match(foo: 'bar') }
      end

      context 'when key is overriden by empty value' do
        params foo: ''

        it { is_expected.to be_empty }
      end

      context 'defaults in sifter' do
        feature do
          defaults foo: 'foo'

          sifter :bar do
            defaults baz: 'baz'

            query_by(foo: 'foo') { scope.tap{ scope.baz = params.baz } }
          end
        end

        params bar: true

        it { is_expected.to match(baz: 'baz') }
      end

      describe 'block usage' do
        feature do
          defaults(foo: 'foo') do
            {voo: 'voo'}
          end

          sifter :bar do
            defaults do
              {baz: 'baz'}
            end
          end
        end

        let(:inherited_query_klass) do
          Class.new(query_klass) do
            defaults do
              {bak: 'bak'}
            end

            query do
              scope.tap do
                scope.foo = params.foo
                scope.voo = params.voo
                scope.baz = params.baz
                scope.bak = params.bak
              end
            end
          end
        end

        let(:query) { inherited_query_klass.new(bar: true) }

        it { is_expected.to match(foo: 'foo', voo: 'voo', baz: 'baz', bak: 'bak') }
      end
    end

    describe 'base scopes' do
      context 'when not specified' do
        let(:query_klass) { Class.new(Parascope::Query) }

        specify { expect{ resolved_scope }.to raise_error(Parascope::UndefinedScopeError) }
      end

      describe 'base_scope in sifter' do
        feature do
          base_scope { OpenStruct.new(foo: 'foo') }

          sifter :bar do
            base_scope { |scope| scope.tap{ scope.bar = 'bar' } }
          end
        end

        params bar: true

        it { is_expected.to match(foo: 'foo', bar: 'bar') }
      end

      describe 'cross-sifter base scopes' do
        feature do
          sifter(:foo) do
            base_scope { OpenStruct.new(foo: true) }

            query { scope.tap{ scope.foo_query = true } }
          end

          sifter(:bar) do
            base_scope { foo_scope }

            query { scope.tap{ scope.bar_query = true } }
          end

          def foo_scope
            resolved_scope(:foo)
          end
        end

        subject{ query_klass.build.resolved_scope(:bar).to_h }

        it { is_expected.to match(foo: true, foo_query: true, bar_query: true) }
      end
    end
  end

  describe 'helpers' do
    describe 'build' do
      let(:query) { query_klass.build }

      specify { expect(query.params).to be_empty }
    end

    describe 'arbitrary readers' do
      let(:user)  { Object.new }
      let(:query) { query_klass.build(user: user) }

      specify { expect(query.user).to be user }
    end

    describe 'query application order control' do
      feature do
        base_scope { OpenStruct.new(value: []) }

        query(index: :last) { scope.tap{ scope.value << 'last' } }
        query { scope.tap{ scope.value << 'bar' } }
        query(index: -1) { scope.tap{ scope.value << 'foo' } }
        query { scope.tap{ scope.value << 'baz' } }
        query(index: :first) { scope.tap{ scope.value << 'first' } }
      end

      let(:query) { query_klass.build }

      subject { query.resolved_scope.to_h }

      it { is_expected.to eq(value: ['first', 'foo', 'bar', 'baz', 'last']) }
    end
  end

  describe 'guard methods' do
    feature do
      guard { scope.foo == 'foo' }

      query_by(:bar) do |bar|
        guard { bar.upcase == 'BAR' }
      end
    end
    let(:scope) { OpenStruct.new(foo: 'foo') }
    let(:query) { query_klass.new(params, scope: scope) }

    describe 'class method' do
      context 'when expectation failed' do
        let(:scope) { OpenStruct.new }

        it 'raises error' do
          expect{ query.resolved_scope }.to raise_error(Parascope::GuardViolationError)
        end
      end

      context 'when expectation is met' do
        it 'does not raise error' do
          expect{ query.resolved_scope }.not_to raise_error
        end
      end

      context 'with custom message' do
        feature do
          raise_on_guard_violation false

          guard('foo should be "foo"') { params[:foo] == 'foo' }
        end

        params foo: 'bar'

        it 'persists violation message' do
          query.resolved_scope
          expect(query.violation).to eq('foo should be "foo"')
        end
      end
    end

    describe 'instance method' do
      context 'when expectation failed' do
        params bar: 'bak'

        it 'raises error' do
          expect{ query.resolved_scope }.to raise_error(Parascope::GuardViolationError)
        end
      end

      context 'when expectation is met' do
        params bar: 'bar'

        it 'does not raise error' do
          expect{ query.resolved_scope }.not_to raise_error
        end
      end

      context 'with custom message' do
        feature do
          raise_on_guard_violation false

          query_by(:bar) do |bar|
            guard('bar should be "bar"') { bar == 'BAR' }
          end
        end

        params bar: 'baz'

        it 'persists violation message' do
          query.resolved_scope
          expect(query.violation).to eq('bar should be "bar"')
        end
      end
    end

    describe 'raise_on_guard_violation option' do
      context 'when disabled' do
        feature do
          raise_on_guard_violation false

          query_by(:bar) do |bar|
            guard { bar.upcase == 'BAR' }
          end
        end

        params bar: 'bak'

        it 'resolves scope to nil and persists violation message' do
          expect(query.resolved_scope).to be_nil
          expect(query.violation).to match(/guard block violated/)
        end
      end
    end
  end

  describe 'aliases' do
    feature do
      base_dataset { OpenStruct.new(foo: 'bar') }

      query { dataset.tap{ |ds| ds.bar = 'baz' } }
    end

    specify '#resolved_dataset' do
      expect(query.resolved_dataset.to_h).to eq(foo: 'bar', bar: 'baz')
    end

    specify '#resolve' do
      expect(query.resolve.to_h).to eq(foo: 'bar', bar: 'baz')
    end

    specify ':dataset initialize option' do
      query = query_klass.build(dataset: OpenStruct.new(baz: 'bak'))
      expect(query.resolve.to_h).to eq(baz: 'bak', bar: 'baz')
    end
  end
end
