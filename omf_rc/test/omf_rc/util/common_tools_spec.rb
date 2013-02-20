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
        @test = OmfRc::ResourceFactory.new(:test)
        2.times { @xmpp.expect(:publish, true, [String, OmfCommon::Message]) }
        @test.log_inform_error "bob"
        @test.log_inform_warn "bob"
      end
    end
  end
end
