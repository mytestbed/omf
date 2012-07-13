require 'test_helper'
require 'omf_rc/resource_proxy/node'

describe OmfRc::ResourceProxy::Node do
  describe "when included in the resource instance" do
    it "must be able to tell registered proxies" do
      OmfRc::ResourceFactory.new(:node, hrn: 'node_test').request_proxies.must_include :node
    end
  end
end
