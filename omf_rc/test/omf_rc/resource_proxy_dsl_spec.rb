require 'test_helper'
require 'omf_rc/resource_proxy_dsl'

describe OmfRc::ResourceProxyDSL do
  before do
    module OmfRc::Util::MockUtility
      include OmfRc::ResourceProxyDSL
      register_utility :mock_utility
      register_configure :alpha
      register_request :alpha
    end

    module OmfRc::ResourceProxy::MockProxy
      include OmfRc::ResourceProxyDSL

      register_proxy :mock_proxy
      utility :mock_utility

      register_hook :before_ready
      register_hook :before_release
      register_configure :bravo
      register_request :bravo
    end
  end

  describe "when included by modules to define resource proxy functionalities" do
    it "must be able to register the modules" do
      OmfRc::ResourceFactory.proxy_list.must_include :mock_proxy
      OmfRc::ResourceFactory.utility_list.must_include :mock_utility
    end

    it "must be able to define methods" do
      OmfRc::Util::MockUtility.method_defined?(:configure_alpha).must_equal true
      OmfRc::Util::MockUtility.method_defined?(:request_alpha).must_equal true
      OmfRc::ResourceProxy::MockProxy.method_defined?(:configure_alpha).must_equal true
      OmfRc::ResourceProxy::MockProxy.method_defined?(:request_alpha).must_equal true
      OmfRc::ResourceProxy::MockProxy.method_defined?(:before_ready).must_equal true
      OmfRc::ResourceProxy::MockProxy.method_defined?(:before_release).must_equal true
    end
  end
end
