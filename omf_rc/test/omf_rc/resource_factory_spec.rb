require 'test_helper'
require 'omf_rc/resource_factory'

describe OmfRc::ResourceFactory do
  describe "when resource proxies loaded" do
    it "must have list of registered proxies and utilities" do
      OmfRc::ResourceFactory.load_default_resource_proxies
      OmfRc::ResourceFactory.proxy_list.must_include :mock
    end

    it "must be able to create new resource proxy" do
      OmfRc::ResourceFactory.load_default_resource_proxies
      mock = OmfRc::ResourceFactory.new(:mock)
      mock.must_be_kind_of OmfRc::ResourceProxy::AbstractResource
      mock.must_respond_to :request_nothing
      mock.request_nothing.must_equal mock.uid
      mock.must_respond_to :configure_nothing
    end
  end
end
