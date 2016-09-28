require "parascope/version"

module Parascope
  UndefinedScopeError = Class.new(StandardError)
  GuardViolationError = Class.new(ArgumentError)

  autoload :Query, "parascope/query"
end
