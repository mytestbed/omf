require 'test_helper'
require 'omf_rc/resource_proxy_dsl'

describe OmfRc::ResourceProxyDSL do
  before do
    module OmfRc::Util::MockUtility
      include OmfRc::ResourceProxyDSL
      configure :alpha

      request :alpha do |resource|
        resource.uid
      end

      def bravo
        "bravo"
      end
    end

    module OmfRc::ResourceProxy::MockProxy
      include OmfRc::ResourceProxyDSL

      register_proxy :mock_proxy

      utility :mock_utility

      hook :before_ready
      hook :before_release

      request :bravo do
        bravo
      end
    end
  end

  describe "when included by modules to define resource proxy functionalities" do
    it "must be able to register the modules" do
      OmfRc::ResourceFactory.proxy_list.must_include :mock_proxy
    end

    it "must be able to define methods" do
      %w(configure_alpha request_alpha bravo).each do |m|
        OmfRc::Util::MockUtility.method_defined?(m.to_sym).must_equal true
      end

      %w(configure_alpha request_alpha before_ready before_release bravo).each do |m|
        OmfRc::ResourceProxy::MockProxy.method_defined?(m.to_sym).must_equal true
      end

      mock_proxy = OmfRc::ResourceFactory.new(:mock_proxy)
      mock_proxy.request_alpha.must_equal mock_proxy.uid
      mock_proxy.request_bravo.must_equal "bravo"
    end
  end
end
