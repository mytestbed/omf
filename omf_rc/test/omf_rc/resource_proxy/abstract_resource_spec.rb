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
    @node = OmfRc::ResourceFactory.new(:node, properties: { pubsub: 'mytestbed.net' })
  end

  describe "when intialised" do
    it "must convert configuration hash into instance methods, and assign the values" do
      @node.type.must_equal 'node'
      @node.properties.must_be_kind_of Hash
      @node.properties.pubsub.must_equal "mytestbed.net"
    end

    it "must have an unique id generated" do
      @node.uid.must_match /.{8}-.{4}-.{4}-.{4}-.{12}/
    end
  end

  describe "when asked to create another resource" do
    it "must return the newly created resource" do
      @node.create(:interface).must_be_kind_of AbstractResource
    end

    it "must add the resource to its created resource list" do
      child = @node.create(:wifi)
      @node.children.must_include child
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      skip
    end
  end

  describe "when asked for the funcitonalities it supports" do
    it "must returned all the properties can be requested & configured" do
      @node.request_available_properties.must_be_kind_of Hashie::Mash
      @node.request_available_properties.configure.must_include :name
      @node.request_available_properties.request.must_include :name
    end
  end
end

