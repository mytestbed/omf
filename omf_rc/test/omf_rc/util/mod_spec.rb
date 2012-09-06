require 'test_helper'
require 'omf_rc/util/mod'

describe OmfRc::Util::Mod do
  describe "when included in the resource proxy" do
    before do
      module OmfRc::ResourceProxy::ModTest
        include OmfRc::ResourceProxyDSL
        register_proxy :mod_test
        utility :mod
      end
    end

    it "will find out a list of modules" do
      OmfCommon::Command.stub :execute, fixture("lsmod") do
        OmfRc::ResourceFactory.new(:mod_test).request_modules.must_include "kvm"
        OmfRc::ResourceFactory.new(:mod_test).request_modules.wont_include "Module"
      end
    end

    it "could load a module" do
      OmfCommon::Command.stub :execute, true do
        OmfRc::ResourceFactory.new(:mod_test).configure_load_module('magic_module').must_equal true
      end
    end
  end
end
