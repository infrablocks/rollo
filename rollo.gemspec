lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rollo/version'
require 'date'

Gem::Specification.new do |spec|
  spec.name = 'rollo'
  spec.version = Rollo::VERSION
  spec.authors = ['Toby Clemson']
  spec.email = ['tobyclemson@gmail.com']

  spec.date = Date.today.to_s
  spec.summary = 'Cluster / service roller for AWS ECS.'
  spec.description = 'Strategies for rolling ECS container instance clusters.'
  spec.homepage = 'https://github.com/infrablocks/rollo'
  spec.license = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) {|f| File.basename(f)}
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6'

  spec.add_dependency 'aws-sdk', '~> 3.0'
  spec.add_dependency 'aws-sdk-ecs', '~> 1.22'
  spec.add_dependency 'wait', '~> 0.5'
  spec.add_dependency 'hollerback', '~> 0.1'
  spec.add_dependency 'thor', '~> 0.20'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 12.3'
  spec.add_development_dependency 'rspec', '~> 3.8'
  spec.add_development_dependency 'aruba', '~> 0.14'
  spec.add_development_dependency 'gem-release', '~> 2.0'
  spec.add_development_dependency 'irbtools', '~> 2.2'
end
