require 'test_helper'
require 'omf_rc/resource_proxy/abstract_resource'

include OmfRc::ResourceProxy

module OmfRc::ResourceProxy
  module Machine
  end

  module Test
  end

  module Test2
  end
end

describe AbstractResource do
  before do
    @resource = AbstractResource.new(type: 'machine', properties: { pubsub: "mytestbed.net" })
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
      @resource.create(:type => 'test2').must_be_kind_of AbstractResource
    end

    it "must add the resource to its created resource list" do
      @test2 = @resource.create(:type => 'test2')
      @resource.children.must_include @test2
    end
  end

  describe "when asked to get a instance of created resource" do
    it "must return a instance of that resource" do
      @test = @resource.create(:type => 'test2', :uid => 'test')
      @resource.get('test').must_equal @test
    end

    it "must raise error when nothing found" do
      proc { @resource.get('bob') }.must_raise Exception
    end
  end

  describe "when asked for the state of the created resources" do
    it "must return a collection of data containing requested properties" do
      @resource.uid = 'readable'
      @resource_1 = @resource.create(type: 'test', uid: 1, properties: { test_key: 'test1' })
      @resource_2 = @resource.create(type: 'test', uid: 2, properties: { test_key: 'test2' })
      @resource_3 = @resource.create(type: 'test2', uid: 3, properties: { test_key: 'test3' })
      properties = @resource.request([:test_key], { type: 'test' })
      properties.size.must_equal 2
      properties[0].test_key.must_equal 'test1'
      properties[1].test_key.must_equal 'test2'
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
      @resource_1 = AbstractResource.new(type: 'test')
      @resource_2 = AbstractResource.new(type: 'test')
      @resource.add(@resource_1).add(@resource_2)
      @resource.release(@resource_1)
      @resource_1.children.must_be_empty
      @resource.children.must_be_empty
    end
  end
end

