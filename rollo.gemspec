# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rollo/version'
require 'date'

files = %w[
  bin
  lib
  CODE_OF_CONDUCT.md
  rake_terraform.gemspec
  Gemfile
  LICENSE.txt
  Rakefile
  README.md
]

Gem::Specification.new do |spec|
  spec.name = 'rollo'
  spec.version = Rollo::VERSION
  spec.authors = ['InfraBlocks Maintainers']
  spec.email = ['maintainers@infrablocks.io']

  spec.summary = 'Cluster / service roller for AWS ECS.'
  spec.description = 'Strategies for rolling ECS container instance clusters.'
  spec.homepage = 'https://github.com/infrablocks/rollo'
  spec.license = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").select do |f|
    f.match(/^(#{files.map { |g| Regexp.escape(g) }.join('|')})/)
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6'

  spec.add_dependency 'aws-sdk', '~> 3.0'
  spec.add_dependency 'aws-sdk-ecs', '~> 1.22'
  spec.add_dependency 'hollerback', '~> 0.1'
  spec.add_dependency 'thor', '>= 0.20', '< 2.0'
  spec.add_dependency 'wait', '~> 0.5'

  spec.add_development_dependency 'aruba', '~> 0.14'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'gem-release', '~> 2.0'
  spec.add_development_dependency 'irbtools', '~> 3.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rake_circle_ci', '~> 0.9'
  spec.add_development_dependency 'rake_github', '~> 0.5'
  spec.add_development_dependency 'rake_gpg', '~> 0.12'
  spec.add_development_dependency 'rake_ssh', '~> 0.4'
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'rubocop', '~> 1.12'
  spec.add_development_dependency 'rubocop-rake', '~> 0.5'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.2'
  spec.add_development_dependency 'simplecov', '~> 0.21'
end
