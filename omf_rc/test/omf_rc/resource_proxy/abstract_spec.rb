require 'test_helper'
require 'omf_rc/resource_proxy/abstract'

include OmfRc::ResourceProxy

describe Abstract do
  before do
    @resource = Abstract.create(:type => 'machine', :properties => {:pubsub => "mytestbed.net"})
  end

  after do
    Sequel::Model.db.from(Abstract.table_name).truncate
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

  describe "when updated" do
    it "must update its values with configuration hash" do
      @resource.update(:name => 'interlagos')
      @resource.name.must_equal 'interlagos'
      @resource.type.must_equal 'machine'
    end
  end

  describe "when asked to create another resource" do
    it "must return the newly created resource" do
      @resource.create(:type => 'interface').must_be_kind_of Abstract
    end

    it "must add the resource to its created resource list" do
      @resource.create(:type => 'interface')
      @interface = Abstract.find(:type => 'interface')
      @resource.children.must_include @interface
      @interface.parent.must_equal @resource
    end
  end

  describe "when asked to get a instance of created resource" do
    it "must return a instance of that resource" do
      @resource.create(:type => 'interface', :uid => 'test')
      @resource.get('test').must_equal Abstract.find(:uid => 'test')
    end

    it "must raise error when nothing found" do
      proc { @resource.get('bob') }.must_raise Exception
    end
  end

  describe "when asked for the state of the created resources" do
    it "must return a collection of data containing requested properties" do
      skip
    end
  end

  describe "when asked to to configure a created resource" do
    it "must convert provided opt hash and update properties" do
      @resource.configure(:ip => '127.0.0.1')
      Abstract.find(:type => 'machine').properties["ip"].must_equal "127.0.0.1"
    end
  end

  describe "when destroyed" do
    it "must destroy itself together with any resources created by it" do
      @resource_1 = Abstract.create(:type => 'test')
      @resource_2 = Abstract.create(:type => 'test')
      @resource.add_child(@resource_1).add_child(@resource_2)
      @resource.destroy
      Abstract.find(:type => 'machine').must_be_nil
      Abstract.filter(:type => 'test').must_be_empty
    end
  end

  describe "when asked to activated" do
    it "must change its state to active" do
      @resource.activate
      @resource.state.must_equal "active"
    end
  end
end

