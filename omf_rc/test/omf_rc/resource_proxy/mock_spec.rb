require 'test_helper'
require 'omf_rc/resource_proxy/mock'

describe OmfRc::ResourceProxy::Mock do
  before do
    @xmpp = MiniTest::Mock.new
    @xmpp.expect(:subscribe, true, [String])

    OmfCommon.stub :comm, @xmpp do
      @mock = OmfRc::ResourceFactory.new(:mock, hrn: 'mock_test')
    end
  end

  describe "when included in the resource instance" do
    it "must provide hooks" do
      @mock.before_ready
      @mock.before_release
    end
  end
end
