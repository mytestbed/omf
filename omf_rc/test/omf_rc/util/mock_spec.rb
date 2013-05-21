# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_rc/util/mock'

describe OmfRc::Util::Mock do
  describe "when included in the resource proxy" do
    before do
      module OmfRc::ResourceProxy::MockTest
        include OmfRc::ResourceProxyDSL
        register_proxy :mock_test
        utility :mock
      end

      @xmpp = MiniTest::Mock.new
      @xmpp.expect(:subscribe, true, [String])
      OmfCommon.stub :comm, @xmpp do
        @mock = OmfRc::ResourceFactory.create(:mock_test)
      end
    end

    it "must have these demo methods available" do
      @mock.request_nothing.must_equal @mock.uid
      @mock.configure_nothing
      @mock.configure_hrn "bob"
      @mock.request_hrn.must_equal "bob"
      @mock.request_resource_proxy_list.must_equal OmfRc::ResourceFactory.proxy_list
      OmfCommon::Command.stub :execute, "bob_os" do
        @mock.request_kernel_version.must_equal "bob_os"
      end
    end
  end
end
