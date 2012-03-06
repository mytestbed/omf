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
    @resource = Mock.create(:type => 'mock', :uid => 'suzuka', :properties => {:mock_property => "test"})
    @resource = Mock.find(:type => 'mock')
  end

  after do
    Sequel::Model.db.from(Mock.table_name).truncate
  end

  describe "when intialised/created" do
    it "must convert configuration hash into instance methods, and assign the values" do
      @resource.type.must_equal 'mock'
      @resource.uid.must_equal 'suzuka'
      @resource.properties.must_be_kind_of Hash
      @resource.properties["mock_property"].must_equal "test"
    end
  end

  describe "when updated" do
    it "must update its values with configuration hash" do
      @resource.update(:uid => 'interlagos')
      @resource.uid.must_equal 'interlagos'
      @resource.type.must_equal 'mock'
    end
  end

  describe "when asked to create another resource" do
    it "must add the resource to its created resource list" do
      @interface = Mock.create(:type => 'interface', :uid => 'i1')
      @resource.add_child(@interface)
      @resource.children.must_include @interface
      @interface.parent.must_equal @resource
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      @resource_1 = Mock.create(:type => 'test', :uid => 'i1')
      @resource_2 = Mock.create(:type => 'test', :uid => 'i2')
      @resource.add_child(@resource_1).add_child(@resource_2)
      @resource.destroy
      Mock.find(:uid => 'suzuka').must_be_nil
      Mock.find(:uid => 'i1').must_be_nil
      Mock.find(:uid => 'i2').must_be_nil
    end
  end

  describe "when asked to activated" do
    it "must change its state to active" do
      @resource.activate
      @resource.state.must_equal "active"
    end
  end
end

