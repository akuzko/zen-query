# frozen_string_literal: true

require_relative "parascope/version"
require_relative "parascope/query"

module Parascope
  UndefinedSubjectError = Class.new(StandardError)
  GuardViolationError = Class.new(ArgumentError)

  Query.raise_on_guard_violation(true)
end
