require 'test_helper'
require 'omf_rc/resource_proxy/abstract'

include OmfRc::ResourceProxy

module OmfRc
  module ResourceProxy
    module Machine
    end

    module Test
    end

    module Interface
    end
  end
end

describe Abstract do
  before do
    @resource = Abstract.new(type: 'machine', properties: { pubsub: "mytestbed.net" })
  end

  describe "when intialised" do
    it "must convert configuration hash into instance methods, and assign the values" do
      @resource.type.must_equal 'machine'
      @resource.properties.must_be_kind_of Hash
      @resource.properties.pubsub.must_equal "mytestbed.net"
    end

    it "must have an unique id generated" do
      @resource.uid.must_match /.{8}-.{4}-.{4}-.{4}-.{12}/
    end
  end

  describe "when asked to create another resource" do
    it "must return the newly created resource" do
      @resource.create(:type => 'interface').must_be_kind_of Abstract
    end

    it "must add the resource to its created resource list" do
      @interface = @resource.create(:type => 'interface')
      @resource.children.must_include @interface
    end
  end

  describe "when asked to get a instance of created resource" do
    it "must return a instance of that resource" do
      @test = @resource.create(:type => 'interface', :uid => 'test')
      @resource.get('test').must_equal @test
    end

    it "must raise error when nothing found" do
      proc { @resource.get('bob') }.must_raise Exception
    end
  end

  describe "when asked for the state of the created resources" do
    it "must return a collection of data containing requested properties" do
      @resource.uid = 'readable'
      @resource_1 = @resource.create(type: 'test', properties: { test_key: 'test' })
      @resource_2 = @resource.create(type: 'test', properties: { test_key: 'test' })
      properties = @resource.request([:test_key], { type: 'test' })
      properties.size.must_equal 2
      properties[0].test_key.must_equal 'test'
      properties[1].test_key.must_equal 'test'
    end
  end

  describe "when asked to to configure a created resource" do
    it "must convert provided opt hash and update properties" do
      @resource.configure(:ip => '127.0.0.1')
      @resource.properties.ip.must_equal "127.0.0.1"
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      @resource_1 = Abstract.new(type: 'test')
      @resource_2 = Abstract.new(type: 'test')
      @resource.add(@resource_1).add(@resource_2)
      @resource.release(@resource_1)
      @resource_1.children.must_be_empty
      @resource.children.must_be_empty
    end
  end

  describe "when asked to activated" do
    it "must change its state to active" do
      @resource.activate
      @resource.state.must_equal "active"
    end
  end
end

