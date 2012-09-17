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
      # Mocking communicator
      @client = Blather::Client.new
      @stream = MiniTest::Mock.new
      @stream.expect(:send, true, [Blather::Stanza])
      @client.post_init @stream, Blather::JID.new('n@d/r')
    end

    it "must be able to log and inform error/warn messages" do
      Blather::Client.stub :new, @client do
        @test = OmfRc::ResourceFactory.new(:test)
        @client.stub :write, true do
          @test.log_inform_error "bob"
          @test.log_inform_warn "bob"
        end
      end
    end
  end
end
