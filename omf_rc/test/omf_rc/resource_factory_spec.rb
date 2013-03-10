require 'test_helper'
require 'omf_rc/resource_factory'

describe OmfRc::ResourceFactory do
  describe "when resource proxies loaded" do
    before do
      @xmpp = MiniTest::Mock.new
      @xmpp.expect(:subscribe, true, [String])
    end

    it "must have list of registered proxies and utilities" do
      OmfRc::ResourceFactory.load_default_resource_proxies
      OmfRc::ResourceFactory.proxy_list.must_include :mock
    end

    it "must be able to create new resource proxy" do
      OmfCommon.stub :comm, @xmpp do
        OmfRc::ResourceFactory.load_default_resource_proxies
        mock = OmfRc::ResourceFactory.new(:mock)
        mock.must_be_kind_of OmfRc::ResourceProxy::AbstractResource
        mock.must_respond_to :request_nothing
        mock.request_nothing.must_equal mock.uid
        mock.must_respond_to :configure_nothing
      end
    end

    it "must be able to load addtional proxies from local folder" do
      Dir.stub :[], ["non_exist_folder/test.rb"] do
        proc do
          OmfRc::ResourceFactory.load_additional_resource_proxies("non_exist_folder")
        end.must_raise LoadError
      end
    end
  end
end
