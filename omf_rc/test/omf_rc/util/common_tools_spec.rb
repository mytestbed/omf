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
    end

    it "must be able to log and inform error/warn messages" do
      @test = OmfRc::ResourceFactory.new(:test)
      @test.comm.stub :publish, 'bob' do
        @test.log_inform_error "bob"
        @test.log_inform_warn "bob"
      end
    end
  end
end
