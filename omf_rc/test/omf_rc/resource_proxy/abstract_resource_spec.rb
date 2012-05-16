require 'test_helper'
require 'omf_rc/resource_factory'

include OmfRc::ResourceProxy

module OmfRc::ResourceProxy
  module Node
    include OmfRc::ResourceProxyDSL
    register_proxy :node
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
      skip
      @node.create(:interface) do |interface|
      end
    end

    it "must add the resource to its created resource list" do
      skip
      @node.create(:wifi) do |wifi|
      end
    end
  end

  describe "when asked for the state of the created resources" do
    it "must call associated request method" do
      skip
    end
  end

  describe "when asked to to configure a created resource" do
    it "must call associated configure method" do
      skip
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      skip
    end
  end
end

