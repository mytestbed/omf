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

      work :bravo do |resource, *random_arguments, block|
        if block
          block.call("working on #{random_arguments.first}")
        else
          random_arguments.first
        end
      end

      request :zulu do |resource, options|
        "You called zulu with: #{options.keys.join('|')}"
      end
    end

    module OmfRc::ResourceProxy::MockRootProxy
      include OmfRc::ResourceProxyDSL

      register_proxy :mock_root_proxy
    end

    module OmfRc::ResourceProxy::MockProxy
      include OmfRc::ResourceProxyDSL

      register_proxy :mock_proxy, :create_by => :mock_root_proxy

      utility :mock_utility

      hook :before_ready
      hook :before_release

      bravo("printing") do |v|
        request :charlie do
          v
        end
      end

      request :delta do
        bravo("printing")
      end
    end

    module OmfRc::ResourceProxy::UselessProxy
      include OmfRc::ResourceProxyDSL

      register_proxy :useless_proxy
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
      mock_proxy.request_delta.must_equal "printing"
      mock_proxy.request_charlie.must_equal "working on printing"
      mock_proxy.bravo("magic", "second parameter") do |v|
        v.must_equal "working on magic"
      end
      mock_proxy.bravo("something", "something else").must_equal "something"
      mock_proxy.request_zulu(country: 'uk').must_equal "You called zulu with: country"
    end

    it "must be able to include utility" do
      Class.new do
        include OmfRc::ResourceProxyDSL
        utility :mock_utility
      end.new.must_respond_to :request_alpha
    end

    it "must log error if utility can't be found" do
      Class.new do
        include OmfRc::ResourceProxyDSL
        utility :wont_be_found_utility
        stub :require, true do
          utility :wont_be_found_utility
        end
      end
    end

    it "must check new proxy's create_by option when ask a proxy create a new proxy" do
      OmfRc::ResourceFactory.new(:mock_root_proxy).create(:mock_proxy)
      OmfRc::ResourceFactory.new(:mock_root_proxy).create(:useless_proxy)
      lambda { OmfRc::ResourceFactory.new(:useless_proxy).create(:mock_proxy) }.must_raise StandardError
    end
  end
end
