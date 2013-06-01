# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

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
      OmfRc::ResourceFactory.proxy_list.must_include :node
    end

    it "must be able to create new resource proxy" do
      OmfCommon.stub :comm, @xmpp do
        OmfRc::ResourceFactory.load_default_resource_proxies
        node = OmfRc::ResourceFactory.create(:node)
        node.must_be_kind_of OmfRc::ResourceProxy::AbstractResource
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
