require 'test_helper'
require 'omf_rc/resource_proxy/abstract'

include OmfRc::ResourceProxy

module OmfRc
  module ResourceProxy
    class Mock < OmfRc::ResourceProxy::Abstract
      many_to_one :parent, :class => self
      one_to_many :children, :key => :parent_id, :class => self
    end
  end
end

describe Mock do
  before do
    @resource = Mock.create(:type => 'mock', :name => 'suzuka', :properties => {:mock_property => "test"})
  end

  after do
    Sequel::Model.db.from(Mock.table_name).truncate
  end

  describe "when intialised/created" do
    it "must convert configuration hash into instance methods, and assign the values" do
      @resource.type.must_equal 'mock'
      @resource.name.must_equal 'suzuka'
      @resource.properties.must_be_kind_of Hash
      @resource.properties["mock_property"].must_equal "test"
    end
  end

  describe "when updated" do
    it "must update its values with configuration hash" do
      @resource.update(:name => 'interlagos')
      @resource.name.must_equal 'interlagos'
      @resource.type.must_equal 'mock'
    end
  end

  describe "when asked to create another resource" do
    it "must add the resource to its created resource list" do
      @interface = Mock.create(:type => 'interface', :name => 'i1')
      @resource.add_child(@interface)
      @resource.children.must_include @interface
      @interface.parent.must_equal @resource
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      @resource_1 = Mock.create(:type => 'test', :name => 'i1')
      @resource_2 = Mock.create(:type => 'test', :name => 'i2')
      @resource.add_child(@resource_1).add_child(@resource_2)
      @resource.destroy
      Mock.find(:name => 'suzuka').must_be_nil
      Mock.find(:name => 'i1').must_be_nil
      Mock.find(:name => 'i2').must_be_nil
    end
  end

  describe "when asked to activated" do
    it "must change its state to active" do
      @resource.activate
      @resource.state.must_equal "active"
    end
  end
end

