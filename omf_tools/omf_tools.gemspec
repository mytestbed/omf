# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "omf_tools/version"

Gem::Specification.new do |s|
  s.name        = "omf_tools"
  s.version     = OmfTools::VERSION
  s.authors     = ["NICTA"]
  s.email       = ["omf-user@lists.nicta.com.au"]
  s.homepage    = "https://www.mytestbed.net"
  s.summary     = %q{OMF utility tools}
  s.description = %q{A set of useful utility tools of OMF, a generic framework for controlling and managing networking testbeds.}

  s.rubyforge_project = "omf_tools"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  s.add_runtime_dependency "xmpp4r", "~> 0.5"
end
