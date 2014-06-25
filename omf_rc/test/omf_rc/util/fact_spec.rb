require 'test_helper'
require 'omf_rc/util/fact'

describe OmfRc::Util::Fact do
  describe "when included in the resource proxy" do
    before do
      module OmfRc::ResourceProxy::Test
        include OmfRc::ResourceProxyDSL
        register_proxy :test
        utility :fact
      end
      mock_comm_in_res_proxy
      mock_topics_in_res_proxy(resources: [:t0])
      @test = OmfRc::ResourceFactory.create(:test, uid: :t0)
    end

    after do
      unmock_comm_in_res_proxy
      @test = nil
    end

    it "must be able to retrieve facts" do
      @test.request_fact_osfamily.must_be_kind_of String
      @test.request_fact_interfaces.must_be_kind_of String
      @test.request_facts.must_be_kind_of Hash
    end
  end
end
