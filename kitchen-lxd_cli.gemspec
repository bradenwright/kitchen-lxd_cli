# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen/driver/lxd_cli_version'

Gem::Specification.new do |spec|
  spec.name          = 'kitchen-lxd_cli'
  spec.version       = Kitchen::Driver::LXD_CLI_VERSION
  spec.authors       = ['Braden Wright']
  spec.email         = ['braden.m.wright@gmail.com']
  spec.description   = %q{A Test Kitchen Driver for LxdCli}
  spec.summary       = spec.description
  spec.homepage      = ''
  spec.license       = 'Apache 2.0'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = []
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'test-kitchen', '~> 1.4.2'

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake'

  spec.add_development_dependency 'cane'
  spec.add_development_dependency 'tailor'
  spec.add_development_dependency 'countloc'
end
