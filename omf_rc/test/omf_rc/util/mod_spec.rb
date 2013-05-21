# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

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
      @command = MiniTest::Mock.new
      @xmpp = MiniTest::Mock.new
      @xmpp.expect(:subscribe, true, [String])
    end

    it "will find out a list of modules" do
      OmfCommon.stub :comm, @xmpp do
        Cocaine::CommandLine.stub(:new, @command) do
          @command.expect(:run, fixture("lsmod"))
          OmfRc::ResourceFactory.create(:mod_test).request_modules.must_include "kvm"
          @command.expect(:run, fixture("lsmod"))
          @xmpp.expect(:subscribe, true, [String])
          OmfRc::ResourceFactory.create(:mod_test).request_modules.wont_include "Module"
          @command.verify
        end
      end
    end

    it "could load a module" do
      OmfCommon.stub :comm, @xmpp do
        Cocaine::CommandLine.stub(:new, @command) do
          @command.expect(:run, true)
          OmfRc::ResourceFactory.create(:mod_test).configure_load_module(name: 'magic_module').must_equal "magic_module loaded"
          @command.verify
        end
      end
    end
  end
end
