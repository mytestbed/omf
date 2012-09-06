require 'test_helper'
require 'omf_rc/resource_proxy/node'

describe OmfRc::ResourceProxy::Node do
  before do
    @node = OmfRc::ResourceFactory.new(:node, hrn: 'node_test')
  end

  describe "when included in the resource instance" do
    it "must be able to tell registered proxies" do
      @node.request_proxies.must_include :node
    end

    it "must provide hooks" do
      @node.before_ready
      @node.before_release
    end
  end
end
