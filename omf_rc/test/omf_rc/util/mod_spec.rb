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

      mock_comm_in_res_proxy
      mock_topics_in_res_proxy(resources: [:mt0])
      @mod_test = OmfRc::ResourceFactory.create(:mod_test, uid: :mt0)
    end

    after do
      unmock_comm_in_res_proxy
      @mod_test = nil
    end

    it "will find out a list of modules" do
      Cocaine::CommandLine.stub(:new, @command) do
        @command.expect(:run, fixture("lsmod"))
        @mod_test.request_modules.must_include "kvm"
        @command.expect(:run, fixture("lsmod"))
        @mod_test.request_modules.wont_include "Module"
        @command.verify
      end
    end

    it "could load a module" do
      Cocaine::CommandLine.stub(:new, @command) do
        @command.expect(:run, true, [Hash])
        @mod_test.configure_load_module(name: 'magic_module').must_equal "magic_module loaded"
        @command.verify
      end
    end
  end
end
