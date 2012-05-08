require 'test_helper'
require 'omf_rc/resource_factory'

include OmfRc::ResourceProxy

module OmfRc::ResourceProxy
  module Node
    include OmfRc::ResourceProxy
    register_proxy :node
  end

  module Interface
    include OmfRc::ResourceProxy
    register_proxy :interface
  end

  module Wifi
    include OmfRc::ResourceProxy
    register_proxy :wifi
  end

  module Mock
    include OmfRc::ResourceProxy
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
      @node.create(:interface) do |interface|
        interface.must_be_kind_of Interface
      end
    end

    it "must add the resource to its created resource list" do
      @node.create(:wifi) do |wifi|
        @node.children.must_include wifi
      end
    end
  end

  describe "when asked to get a instance of created resource" do
    it "must return a instance of that resource" do
      @node.create(:wifi) do |wifi|
        @node.get(wifi.uid).must_equal wifi
      end
    end

    it "must raise error when nothing found" do
      proc { @node.get('bob') }.must_raise Exception
    end
  end

  describe "when asked for the state of the created resources" do
    it "must return a collection of data containing requested properties" do
      @node.uid = 'readable'
      @resource_1 = @node.create(:interface, uid: 1, properties: { test_key: 'test1' })
      @resource_2 = @node.create(:interface, uid: 2, properties: { test_key: 'test2' })
      @resource_3 = @node.create(:wifi, uid: 3, properties: { test_key: 'test3' })
      @node.request([:test_key], { type: 'interface' }) do |properties|
        properties.size.must_equal 2
        properties[0].test_key.must_equal 'test1'
        properties[1].test_key.must_equal 'test2'
      end
    end
  end

  describe "when asked to to configure a created resource" do
    it "must convert provided opt hash and update properties" do
      @node.configure(ip: '127.0.0.1') do
        @node.properties.ip.must_equal "127.0.0.1"
      end
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      @node.create(:wifi) do |wifi|
        wifi.create(:mock) do |mock|
          @node.release(wifi) do
            wifi.children.must_be_empty
            @node.children.must_be_empty
          end
        end
      end
    end
  end
end

