require 'test_helper'
require 'omf_rc/resource_proxy/abstract'

describe OmfRc::ResourceProxy::Abstract do
  before do
    @resource = OmfRc::ResourceProxy::Abstract.create(:type => 'machine', :name => 'suzuka', :properties => {:pubsub => "mytestbed.net"})
  end

  after do
    Sequel::Model.db.from(:abstracts).truncate
  end

  describe "when intialised/created" do
    it "must convert configuration hash into instance methods, and assign the values" do
      @resource.type.must_equal 'machine'
      @resource.name.must_equal 'suzuka'
      @resource.properties.must_be_kind_of Hash
      @resource.properties["pubsub"].must_equal "mytestbed.net"
    end
  end

  describe "when updated" do
    it "must update its values with configuration hash" do
      @resource.update(:name => 'interlagos')
      @resource.name.must_equal 'interlagos'
      @resource.type.must_equal 'machine'
    end
  end

  describe "when asked to create another resource" do
    it "must add the resource to its created resource list" do
      @interface = OmfRc::ResourceProxy::Abstract.create(:type => 'interface', :name => 'i1')
      @resource.add_child(@interface)
      @resource.children.must_include @interface
      @interface.parent.must_equal @resource
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      @resource_1 = OmfRc::ResourceProxy::Abstract.create(:type => 'test', :name => 'i1')
      @resource_2 = OmfRc::ResourceProxy::Abstract.create(:type => 'test', :name => 'i2')
      @resource.add_child(@resource_1).add_child(@resource_2)
      @resource.destroy
      OmfRc::ResourceProxy::Abstract.find(:name => 'suzuka').must_be_nil
      OmfRc::ResourceProxy::Abstract.find(:name => 'i1').must_be_nil
      OmfRc::ResourceProxy::Abstract.find(:name => 'i2').must_be_nil
    end
  end
end

