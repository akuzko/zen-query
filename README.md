# Parascope

Param-based scope generation.

[![build status](https://secure.travis-ci.org/akuzko/parascope.png)](http://travis-ci.org/akuzko/parascope)
[![github release](https://img.shields.io/github/release/akuzko/parascope.svg)](https://github.com/akuzko/parascope/releases)

---

This gem provides a `Parascope::Query` class with a declarative and convenient API
to build scopes (ActiveRecord relations or arbitrary objects) dynamically, based
on parameters passed to query object on initialization.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'parascope'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install parascope

## Usage

Despite the fact `parascope` was intended to help building ActiveRecord relations
via scopes or query methods, it's usage is not limited to ActiveRecord cases and
may be used with any arbitrary classes and objects. In fact, the only gem's dependency
is `hashie`, and for development and testing, `OpenStruct` instance is used as a
generic scope object. However, ActiveRecord examples should illustrate gem's usage
in the best way.

### API

`parascope` provides `Parascope::Query` class, descendants of which should declare
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
  resolved_scope(:paginated)
end
```

- `base_scope(&block)` method is used to define a base scope as a starting point
  of scope-generating process. If this method is called from `sift_by` block,
  top-level base scope is yielded to the method block. Note that `base_scope` will
  not be called if query is initialized with a given scope.

  *Alias:* `base_dataset`

*Examples:*

```ruby
base_scope { company.users }

sifter :with_department do
  base_scope { |scope| scope.joins(:department) }
end
```

- `defaults(hash)` method is used to declare default query params that are reverse
  merged with params passed on query initialization. When used in `sift_by` block,
  hashes are merged altogether.

*Examples:*

```ruby
defaults only_active: true

sifter :paginated do
  # sifter defaults are merged with higher-level defaults:
  defaults page: 1, per_page: 25
end
```

- `guard(message = nil, &block)` defines a guard instance method block (see instance methods
  bellow). All such blocks are executed before query object resolves scope via
  `resolve_scope` method. Optional `message` may be supplied to provide more informative
  error message.

*Examples:*

```ruby
sift_by(:sort_col, :sort_dir) do |scol, sdir|
  # will raise Parascope::GuardViolationError on scope resolution if
  # params[:sort_dir] is not 'asc' or 'desc'
  guard(':sort_dir should be "asc" or "desc"') do
    sdir.downcase.in?(%w(asc desc))
  end

  base_scope { |scope| scope.order(scol => sdir) }
end
```

- `raise_on_guard_violation(value)` allows to specify whether or not exception should be raised
  whenever any guard block is violated during scope resolution. When set to `false`, in case
  of any violation, `resolved_scope` will return `nil`, and query will have `violation` property
  set with value corresponding to the message of violated block. Default option value is `true`.

*Examples:*

```ruby
raise_on_guard_violation false

sift_by(:sort_col, :sort_dir) do |scol, sdir|
  guard(':sort_dir should be "asc" or "desc"') do
    sdir.downcase.in?(%w(asc desc))
  end

  base_scope { |scope| scope.order(scol => sdir) }
end
```

```ruby
query = UsersQuery.new(sort_col: 'id', sort_dir: 'there')
query.resolved_scope # => nil
query.violation # => ":sort_dir should be \"asc\" or \"desc\""
```

- `build(scope: nil, **attributes)` initializes a query with empty params. Handy when
  query depends only passed attributes and internal logic. Also useful in specs.

*Examples:*

```ruby
query = UsersQuery.build(scope: users_scope)
# the same as UsersQuery.new({}, scope: users_scope)
```

#### Instance Methods

- `initialize(params, scope: nil, dataset: nil, **attributes)` initializes a query with
  `params`, an optional scope can be passed as `:scope` or `:dataset` option. If passed,
  it will be used instead of `base_scope`. All additionally passed options are accessible
  via reader methods in query blocks and elsewhere.

*Examples:*

```ruby
query = UsersQuery.new(query_params, company: company)
```

- `params` returns a parameters passed in initialization. Is a `Hashie::Mash` instance,
  thus, values can be accessible via reader methods.

- `scope` "current" scope of query object. For an initialized query object corresponds
  to base scope. Primary usage is to call this method in `query_by` blocks and return
  it's mutated version corresponding to passed `query_by` arguments.

  *Alias:* `dataset`

- `guard(&block)` executes a passed `block`. If this execution returns falsy value,
  `GuardViolationError` is raised. You can use this method to ensure safety of param
  values interpolation to a SQL string in a `query_by` block for example.

*Examples:*

```ruby
query_by(:sort_col, :sort_dir) do |scol, sdir|
  # will raise Parascope::GuardViolationError on scope resolution if
  # params[:sort_dir] is not 'asc' or 'desc'
  guard { sdir.downcase.in?(%w(asc desc)) }

  scope.order(scol => sdir)
end
```

- `resolved_scope(*presence_keys, override_params = {})` returns a resulting scope
  generated by all queries and sifted queries that fit to query params applied to
  base scope. Optionally, additional params may be passed to override the ones passed on
  initialization. For convinience, you may pass list of keys that should be resolved
  to `true` with params (for example, `resolved_scope(:with_projects)` instead of
  `resolved_scope(with_projects: true)`). It's the main `Query` instance method that
  returns the sole purpose of it's instances.

  *Aliases:* `resolved_dataset`, `resolve`

*Examples:*

```ruby
defaults only_active: true

base_scope { company.users }

query_by(:only_active) { scope.active }

sifter :with_departments do
  base_scope { scope.joins(:departments) }

  query_by(:department_name) { |name| scope.where(departments: {name: name}) }
end

def users
  @users ||= resolved_scope
end

# you can use options to overwrite defaults:
def all_users
  resolved_scope(only_active: false)
end

# or to apply a sifter with additional params:
def managers
  resolved_scope(:with_departments, department_name: 'managers')
end
```

### Composite usage example with ActiveRecord Relation as a scope

```ruby
class UserQuery < Parascope::Query
  defaults only_active: true

  base_scope { company.users }

  query_by(:only_active) { scope.active }

  query_by(:birthdate) { |date| scope.by_birtdate(date) }

  query_by :name do |name|
    scope.where("CONCAT(first_name, ' ', last_name) LIKE ?", "%#{name}%")
  end

  sift_by :sort_column, :sort_direction do |scol, sdir|
    guard { sdir.to_s.downcase.in?(%w(asc desc)) }

    base_scope { |scope| scope.order(scol => sdir) }

    query_by(sort_column: 'name') do
      scope.reorder("CONCAT(first_name, ' ', last_name) #{sdir}")
    end
  end

  sifter :with_projects do
    base_scope { |scope| scope.joins(:projects) }

    query_by :project_name do |name|
      scope.where(projects: {name: name})
    end
  end

  def users
    @users ||= resolved_scope
  end

  def project_users
    @project_users ||= resolved_scope(:with_projects)
  end
end

params = {name: 'John', sort_column: 'name', sort_direction: 'DESC', project_name: 'ExampleApp'}

query = UserQuery.new(params, company: some_company)

query.project_users # => this is the same as:
# some_company.users
#   .active
#   .joins(:projects)
#   .where("CONCAT(first_name, ' ', last_name) LIKE ?", "%John%")
#   .where(projects: {name: 'ExampleApp'})
#   .order("CONCAT(first_name, ' ', last_name) DESC")
```

### A Note on `base_scope` Blocks

Keep in mind that _all_ `base_scope` blocks are
**applied only if query object was initialized without explicit scope option**,
i.e. if your Query class has a sifter with mandatory scope modification, and
you initialize your query objects with explicit scope, you most likely want
to use unoptional `query` block within sifter definition. For example,

```rb
class MyQuery < Parascope::Query
  sifter :with_projects do
    query { scope.joins(:projects) }

    # ...
  end
end

query = MyQuery.new(params, scope: some_scope)
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
class ApplicationQuery < Parascope::Query
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

Bug reports and pull requests are welcome on GitHub at https://github.com/akuzko/parascope.


## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

