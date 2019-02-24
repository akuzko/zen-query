require "parascope/version"

module Parascope
  UndefinedScopeError = Class.new(StandardError)
  GuardViolationError = Class.new(ArgumentError)

  autoload :Query, "parascope/query"

  Query.raise_on_guard_violation true
end
