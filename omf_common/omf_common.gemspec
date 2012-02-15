# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "omf_common/version"

Gem::Specification.new do |s|
  s.name        = "omf_common"
  s.version     = OmfCommon::VERSION
  s.authors     = ["NICTA"]
  s.email       = ["omf-user@lists.nicta.com.au"]
  s.homepage    = "https://omf.mytestbed.net"
  s.summary     = %q{Common library of OMF}
  s.description = %q{Common library of OMF, a generic framework for controlling and managing networking testbeds.}

  s.rubyforge_project = "omf_common"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "xmpp4r", "~> 0.5"
  s.add_runtime_dependency "log4r", "~> 1.1"
end
