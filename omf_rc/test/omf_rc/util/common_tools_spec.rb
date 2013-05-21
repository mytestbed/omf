# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_rc/util/common_tools'

describe OmfRc::Util::CommonTools do
  
  describe "when included in the resource proxy" do
    before do
      module OmfRc::ResourceProxy::Test
        include OmfRc::ResourceProxyDSL
        register_proxy :test
        utility :common_tools
      end

      @xmpp = MiniTest::Mock.new
      @xmpp.expect(:subscribe, true, [String])
    end

    it "must be able to log and inform error/warn messages" do
      OmfCommon.stub :comm, @xmpp do
        @test = OmfRc::ResourceFactory.create(:test)
        2.times { @xmpp.expect(:publish, true, [String, OmfCommon::Message]) }
        @test.log_inform_error "bob"
        @test.log_inform_warn "bob"
      end
    end
  end
end
