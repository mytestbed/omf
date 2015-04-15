# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "omf_common/version"

Gem::Specification.new do |s|
  s.name        = "omf_common"
  s.version     = OmfCommon::VERSION
  s.authors     = ["NICTA"]
  s.email       = ["omf-user@lists.nicta.com.au"]
  s.homepage    = "http://omf.mytestbed.net"
  s.summary     = %q{Common library of OMF}
  s.description = %q{Common library of OMF, a generic framework for controlling and managing networking testbeds.}
  s.required_ruby_version = '>= 1.9.3'
  s.license = 'MIT'

  s.rubyforge_project = "omf_common"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "minitest"
  s.add_development_dependency "evented-spec", "~> 1.0.0.beta"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "pry"
  s.add_development_dependency "mocha"

  s.add_runtime_dependency "eventmachine"
  s.add_runtime_dependency "logging", "~> 1.8.2"
  s.add_runtime_dependency "hashie"
  s.add_runtime_dependency "oml4r", "~> 2.10.1"
  s.add_runtime_dependency "amqp"
  s.add_runtime_dependency "uuidtools"

  s.add_runtime_dependency "oj"
  s.add_runtime_dependency "oj_mimic_json"
  s.add_runtime_dependency "json-jwt"
end
