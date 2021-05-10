# frozen_string_literal: true

require_relative "lib/parascope/version"

Gem::Specification.new do |spec|
  spec.name          = "parascope"
  spec.version       = Parascope::VERSION
  spec.authors       = ["Artem Kuzko"]
  spec.email         = ["a.kuzko@gmail.com"]

  spec.summary       = "Builds a params-sifted scope"
  spec.description   = 'Parascope::Query class provides a way to dynamically
    apply scopes or ActiveRecord query methods based on passed params with a
    declarative and convenient API'
  spec.homepage      = "https://github.com/akuzko/parascope"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/akuzko/parascope.git"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-nav"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rspec-its", "~> 1.2"
  spec.add_development_dependency "rubocop", "~> 0.80"
end
