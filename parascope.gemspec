# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'parascope/version'

Gem::Specification.new do |spec|
  spec.name          = "parascope"
  spec.version       = Parascope::VERSION
  spec.authors       = ["Artem Kuzko"]
  spec.email         = ["a.kuzko@gmail.com"]

  spec.summary       = %q{Builds a params-siftered scope}
  spec.description   = %q{Parascope::Query class provides a way to dynamically
    apply scopes or ActiveRecord query methods based on passed params with a
    declarative and convenient API}
  spec.homepage      = "https://github.com/akuzko/parascope"
  spec.license       = "MIT"

  spec.required_ruby_version = '>= 2.0.0'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "hashie"

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-nav"
end
