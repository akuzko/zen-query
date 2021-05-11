# Zen::Query

Param-based scope (relation, dataset) generation.

[![build status](https://secure.travis-ci.org/akuzko/zen-query.png)](http://travis-ci.org/akuzko/zen-query)
[![github release](https://img.shields.io/github/release/akuzko/zen-query.svg)](https://github.com/akuzko/zen-query/releases)

---

This gem provides a `Zen::Query` class with a declarative and convenient API
to build scopes (ActiveRecord relations or arbitrary objects) dynamically, based
on parameters passed to query object on initialization.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'zen-query'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install zen-query

## Usage

Despite the fact `zen-query` was intended to help building ActiveRecord relations
via scopes or query methods, it's usage is not limited to ActiveRecord cases and
may be used with any arbitrary classes and objects. In fact, for development and
testing, `OpenStruct` instance is used as a generic subject. However, ActiveRecord
examples should illustrate gem's usage in the best way.

For most examples in this README, `scope` method is used as accessor to
current subject value. This behavior is easily achieved via `Query.alias_subject_name(:scope)`
method call.

### API

`zen-query` provides `Zen::Query` class, descendants of which should declare
scope manipulations using `query_by`, `sift_by` and other class methods bellow.

#### Class Methods

- `query_by(*presence_fields, **value_fields, &block)` declares a scope-generation query
  block that will be executed if, and only if all values of query params at the keys of
  `presence_fields` are present in activesupport's definition of presence and all `value_fields`
  are present in query params as is. The block is executed in context of query
  object. All values of specified params are yielded to the block. If the block
  returns a non-nil value, it becomes a new scope for subsequent processing. Of course,
  there can be multiple `query_by` block definitions. Methods accepts additional options:
  - `:index` - allows to specify order of query block applications. By default all query
    blocks have index of 0. This option also accepts special values `:first` and `:last` for
    more convenient usage. Queries with the same value of `:index` option are applied in
    order of declaration.
  - `:if` - specifies condition according to which query should be applied. If Symbol
    or String is passed, calls corresponding method. If Proc is passed, it is executed
    in context of query object. Note that this is optional condition, and does not
    overwrite original param-based condition for a query block that should always be met.
  - `:unless` - the same as `:if` option, but with reversed boolean check.

- `query_by!(*fields, &block)` declares scope-generation block that is always executed
  (unless `:if` and/or `:unless` options are used). All values in params at `fields` keys are
  yielded to the block. As `query_by`, accepts `:index`, `:if` and `:unless` options.

- `query(&block)` declares scope-generation block that is always executed (unless `:if`
  and/or `:unless` options are used). As `query_by`, accepts `:index`, `:if` and `:unless`
  options.

*Examples:*

```ruby
# executes block only when params[:department_id] is non-empty:
query_by(:department_id) { |id| scope.where(department_id: id) }

# executes block only when params[:only_active] == 'true':
query_by(only_active: 'true') { scope.active }

# executes block only when *both* params[:first_name] and params[:last_name]
# are present:
query_by(:first_name, :last_name) do |first_name, last_name|
  scope.where(first_name: first_name, last_name: last_name)
end

# if query block returns nil, scope will remain intact:
query { scope.active if only_active? }

# conditional example:
query(if: :include_inactive?) { scope.with_inactive }

def include_inactive?
  company.settings.include_inactive?
end
```

- `sift_by(*presence_fields, **value_fields, &block)` method is used to hoist sets of
  query definitions that should be applied if, and only if, all specified values
  match criteria in the same way as in `query_by` method. Just like `query_by` method,
  values of specified fields are yielded to the block. Accepts the same options as
  it's `query_by` counterpart. Such `sift_by` definitions may be nested in any depth.

- `sift_by!(*fields, &block)` declares a sifter block that is always applied (unless
  `:if` and/or `:unless` options are used). All values in params at specified `fields`
  are yielded to the block.

- `sifter` alias for `sift_by`. Results in a more readable construct when a single
  presence field is passed. For example, `sifter(:paginated)`.

*Examples:*

```ruby
sift_by(:search_value, :search_type) do |value|
  # definitions in this block will be applied only if *both* params[:search_value]
  # and params[:search_type] are present

  search_value = "%#{value}%"

  query_by(search_type: 'name') { scope.name_like(value) }
  query_by(search_type: 'email') { scope.where("users.email LIKE ?", search_value) }
end

sifter :paginated do
  query_by(:page, :per_page) do |page, per|
    scope.page(page).per(per)
  end
end

def paginated_records
  resolve(:paginated)
end
```

- `subject(&block)` method is used to define a base subject as a starting point
  of subject-generating process. Note that `subject` will not be evaluated if
  query is initialized with a given subject.

*Examples:*

```ruby
subject { User.all }
```

- `defaults(&block)` method is used to declare default query params that are
  reverse merged with params passed on query initialization. When used in `sift_by`
  block, hashes are merged altogether. Accepts a `block`, it's return value
  will be evaluated and merged on query object instantiation, allowing to have
  dynamic default params values.

*Examples:*

```ruby
defaults { { later_than: 1.week.ago } }

sifter :paginated do
  # sifter defaults are merged with higher-level defaults:
  defaults { { page: 1, per_page: 25 } }
end
```

- `guard(message = nil, &block)` defines a guard instance method block (see instance methods
  bellow). All such blocks are executed before query object resolves scope via
  `resolve_scope` method. Optional `message` may be supplied to provide more informative
  error message.

*Examples:*

```ruby
sift_by(:sort_col, :sort_dir) do |scol, sdir|
  # will raise Zen::Query::GuardViolationError on scope resolution if
  # params[:sort_dir] is not 'asc' or 'desc'
  guard(':sort_dir should be "asc" or "desc"') do
    sdir.downcase.in?(%w(asc desc))
  end

  query { scope.order(scol => sdir) }
end
```

- `raise_on_guard_violation(value)` allows to specify whether or not exception should be raised
  whenever any guard block is violated during scope resolution. When set to `false`, in case
  of any violation, `resolve` will return `nil`, and query will have `violation` property
  set with value corresponding to the message of violated block. Default option value is `true`.

*Examples:*

```ruby
raise_on_guard_violation false

sift_by(:sort_col, :sort_dir) do |scol, sdir|
  guard(':sort_dir should be "asc" or "desc"') do
    sdir.downcase.in?(%w(asc desc))
  end

  query { scope.order(scol => sdir) }
end
```

```ruby
query = UsersQuery.new(sort_col: 'id', sort_dir: 'there')
query.resolve # => nil
query.violation # => ":sort_dir should be \"asc\" or \"desc\""
```

- `attributes(*attribute_names)` allows to specify additional attributes that can be passed
  to query object on initialization. For each given attribute name, reader method is generated.

#### Instance Methods

- `initialize(params: {}, subject: nil, **attributes)` initializes a query with
  `params`, an optional subject and attributes. If subject is aliased, corresponding
  key should be used instead. The rest of attributes are only accepted if they were
  declared via `attributes` class method call.

*Examples:*

```ruby
query = UsersQuery.new(params: query_params, company: company)
```

- `params` returns a parameters passed in initialization, reverse merged with query
  defaults.

- `subject` "current" subject of query object. For an initialized query object corresponds
  to base subject. Primary usage is to call this method in `query_by` blocks and return
  it's mutated version corresponding to passed `query_by` arguments.

  Can be aliased to more suitable name with `Query.alias_subject_name` class method.

- `guard(&block)` executes a passed `block`. If this execution returns falsy value,
  `GuardViolationError` is raised. You can use this method to ensure safety of param
  values interpolation to a SQL string in a `query_by` block for example.

*Examples:*

```ruby
query_by(:sort_col, :sort_dir) do |scol, sdir|
  # will raise Zen::Query::GuardViolationError on scope resolution if
  # params[:sort_dir] is not 'asc' or 'desc'
  guard { sdir.downcase.in?(%w(asc desc)) }

  scope.order(scol => sdir)
end
```

- `resolve(*presence_keys, override_params = {})` returns a resulting scope
  generated by all queries and sifted queries that fit to query params applied to
  base scope. Optionally, additional params may be passed to override the ones passed on
  initialization. For convinience, you may pass list of keys that should be resolved
  to `true` with params (for example, `resolve(:with_projects)` instead of
  `resolve(with_projects: true)`). It's the main `Query` instance method that
  returns the sole purpose of it's instances.

*Examples:*

```ruby
defaults { { only_active: true } }

subject { company.users }

query_by(:only_active) { subject.active }

sifter :with_departments do
  query { subject.joins(:departments) }

  query_by(:department_name) do |name|
    subject.where(departments: { name: name })
  end
end

def users
  @users ||= resolve
end

# you can use options to overwrite defaults:
def all_users
  resolve(only_active: false)
end

# or to apply a sifter with additional params:
def managers
  resolve(:with_departments, department_name: 'managers')
end
```

### Composite usage example with ActiveRecord Relation as a subject, aliased as `:relation`

```ruby
class UserQuery < Zen::Query
  alias_subject_name :relation

  attributes :company

  defaults { { only_active: true } }

  relation { company.users }

  query_by(:only_active) { relation.active }

  query_by(:birthdate) { |date| relation.by_birtdate(date) }

  query_by :name do |name|
    relation.where("CONCAT(first_name, ' ', last_name) LIKE :name", name: "%#{name}%")
  end

  sift_by :sort_column, :sort_direction do |scol, sdir|
    guard { sdir.to_s.downcase.in?(%w(asc desc)) }

    query { relation.order(scol => sdir) }

    query_by(sort_column: 'name') do
      relation.reorder("CONCAT(first_name, ' ', last_name) #{sdir}")
    end
  end

  sifter :with_projects do
    query { relation.joins(:projects) }

    query_by :project_name do |name|
      scope.where(projects: { name: name })
    end
  end

  def users
    @users ||= resolve
  end

  def project_users
    @project_users ||= resolve(:with_projects)
  end
end

params = { name: 'John', sort_column: 'name', sort_direction: 'DESC', project_name: 'ExampleApp' }

query = UserQuery.new(params: params, company: some_company)

query.project_users # => this is the same as:
# some_company.users
#   .active
#   .joins(:projects)
#   .where("CONCAT(first_name, ' ', last_name) LIKE ?", "%John%")
#   .where(projects: { name: 'ExampleApp' })
#   .order("CONCAT(first_name, ' ', last_name) DESC")
```

### Hints and Tips

- Keep in mind that query classes are just plain Ruby classes. All `sifter`,
`query_by` and `guard` declarations are inherited, as well as default params
declared by `defaults` method. Thus, you can define a BaseQuery with common
definitions as a base class for queries in your application. Or you can define
query API blocks in some module's `included` callback to share common definitions
via module inclusion.

- Being plain Ruby classes also means you can easily extend default functionality
for your needs. For example, if you're querying ActiveRecord relations, and your
primary use case looks like

```ruby
query_by(:some_field_id) { |id| scope.where(some_field_id: id) }
```
you can do the following to make things more DRY:

```ruby
class ApplicationQuery < Zen::Query
  def self.query_by(*fields, &block)
    block ||= default_query_block(fields)
    super(*fields, &block)
  end

  def self.default_query_block(fields)
    ->(*values){ scope.where(Hash[fields.zip(values)]) }
  end
  private_class_method :default_query_block
end
```

and then you can simply call

```ruby
class UsersQuery < ApplicationQuery
  base_scope { company.users }

  query_by :first_name
  query_by :last_name
  query_by :city, :street_address
end
```

Or you can go a little further and declare a class method

```ruby
class ApplicationQuery
  def self.query_by_fields(*fields)
    fields.each do |field|
      query_by field
    end
  end
end
```

and then

```ruby
class UserQuery < ApplicationQuery
  query_by_fields :first_name, :last_name, :department_id
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/akuzko/zen-query.


## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

