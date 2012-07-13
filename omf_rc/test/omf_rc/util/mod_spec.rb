require 'test_helper'
require 'mock_helper'
require 'omf_rc/util/mod'

describe OmfRc::Util::Mod do
  describe "when included in the resource instance" do
    before do
      module OmfRc::ResourceProxy::ModTest
        include OmfRc::ResourceProxyDSL
        register_proxy :mod_test
        utility :mod
      end
    end

    after do
      mock_verify_execute
    end

    it "will find out a list of modules" do
      mock_execute(fixture("lsmod"), "lsmod")
      OmfRc::ResourceFactory.new(:mod_test).request_modules.must_include "kvm"
      OmfRc::ResourceFactory.new(:mod_test).request_modules.wont_include "Module"
    end

    it "could load a module" do
      mock_execute(nil, /modprobe */)
      OmfRc::ResourceFactory.new(:mod_test).configure_load_module('magic_module').must_be_nil
    end
  end
end
