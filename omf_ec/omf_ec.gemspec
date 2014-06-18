# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
$:.push File.expand_path("../../omf_common/lib", __FILE__)
require "omf_ec/version"

Gem::Specification.new do |s|
  s.name        = "omf_ec"
  s.version     = OmfEc::VERSION
  s.authors     = ["NICTA"]
  s.email       = ["omf-user@lists.nicta.com.au"]
  s.homepage    = "http://omf.mytestbed.net"
  s.summary     = %q{OMF experiment controller}
  s.description = %q{Experiment controller of OMF, a generic framework for controlling and managing networking testbeds.}
  s.required_ruby_version = '>= 1.9.3'
  s.license = 'MIT'

  s.rubyforge_project = "omf_ec"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  s.add_development_dependency "minitest"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "pry"
  s.add_development_dependency "mocha"
  s.add_development_dependency "evented-spec"

  s.add_runtime_dependency "omf_common", "= #{OmfCommon::VERSION}"
  s.add_runtime_dependency "sequel"
end
