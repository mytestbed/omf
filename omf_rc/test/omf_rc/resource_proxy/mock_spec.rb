require 'test_helper'
require 'omf_rc/resource_proxy/abstract'

include OmfRc::ResourceProxy

module OmfRc::ResourceProxy
  module Mock
    def test
    end

    def configure_property(property, value)
      super
      raise StandardError, 'Get your attention'
    end
  end
end

describe Mock do
  before do
    @resource = Abstract.create(:type => 'mock', :uid => 'suzuka', :properties => {:mock_property => "test"})
    @resource = Abstract.find(:type => 'mock')
  end

  after do
    Sequel::Model.db.from(Abstract.table_name).truncate
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
      @interface = Abstract.create(:type => 'mock', :uid => 'i1')
      @i2 = Abstract.create(:type => 'mock', :uid => 'i2')
      @resource.add_child(@interface)
      @resource.add_child(@i2)
      @resource.children.must_include @interface
      @resource.children.must_include @i2
      @interface.parent.must_equal @resource
    end
  end

  describe "when child resource with a known type" do
    it "must load methods from related module correctly" do
      @mock = @resource.create(type: 'mock', uid: 'mock')
      @mock.must_respond_to :test
      proc { @mock.must_send [@mock, :configure_property, 'test', 'test'] }.must_raise StandardError
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      @resource_1 = Abstract.create(:type => 'mock', :uid => 'i1')
      @resource_2 = Abstract.create(:type => 'mock', :uid => 'i2')
      @resource.add_child(@resource_1).add_child(@resource_2)
      @resource.destroy
      Abstract.find(:uid => 'suzuka').must_be_nil
      Abstract.find(:uid => 'i1').must_be_nil
      Abstract.find(:uid => 'i2').must_be_nil
    end
  end

  describe "when asked to activated" do
    it "must change its state to active" do
      @resource.activate
      @resource.state.must_equal "active"
    end
  end
end

