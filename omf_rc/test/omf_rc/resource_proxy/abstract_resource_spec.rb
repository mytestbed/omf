require 'test_helper'
require 'omf_rc/resource_factory'

include OmfRc::ResourceProxy

module OmfRc::ResourceProxy
  module Node
    include OmfRc::ResourceProxyDSL
    register_proxy :node

    register_request :name
    register_configure :name
  end

  module Interface
    include OmfRc::ResourceProxyDSL
    register_proxy :interface
  end

  module Wifi
    include OmfRc::ResourceProxyDSL
    register_proxy :wifi
  end

  module Mock
    include OmfRc::ResourceProxyDSL
    register_proxy :mock
  end
end

describe AbstractResource do
  before do
    @node = OmfRc::ResourceFactory.new(:node, { hrn: 'default_node' })
  end

  describe "when intialised" do
    it "must convert configuration hash into instance methods, and assign the values" do
      @node.type.must_equal 'node'
    end

    it "must have an unique id generated" do
      @node.uid.must_match /.{8}-.{4}-.{4}-.{4}-.{12}/
      @node.request_uid.must_match /.{8}-.{4}-.{4}-.{4}-.{12}/
    end
  end

  describe "when asked to create another resource" do
    it "must return the newly created resource" do
      @node.create(:interface).must_be_kind_of AbstractResource
    end

    it "must add the resource to its created resource list" do
      child = @node.create(:wifi, { hrn: 'default_wifi' })
      @node.children.must_include child
      @node.request_child_resources[child.uid].must_equal 'default_wifi'
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      @node.release
      @node.frozen?.must_equal true
      @node.children.must_be_empty
    end
  end

  describe "when asked for the funcitonalities it supports" do
    it "must returned all the properties can be requested & configured" do
      @node.request_available_properties.must_be_kind_of Hashie::Mash
      @node.request_available_properties.configure.must_include :name
      @node.request_available_properties.request.must_include :name
    end

    it "must be able to request and configure some common properties" do
      @node.request_hrn.must_equal 'default_node'
      @node.configure_hrn('bob')
      @node.request_hrn.must_equal 'bob'
    end
  end
end


