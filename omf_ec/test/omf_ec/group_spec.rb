require 'test_helper'
require 'omf_ec/group'

describe OmfEc::Group do
  before do
    OmfEc.stubs(:subscribe_and_monitor)
  end

  after do
    OmfEc.unstub(:subscribe_and_monitor)
  end

  describe "when initialised" do
    it "must be generate unique id if :unique option is on" do
      OmfEc::Group.new('bob').id.wont_equal 'bob'
    end

    it "must use name as id if :unique option is off" do
      OmfEc::Group.new('bob', unique: false).id.must_equal 'bob'
    end
  end

  describe "when used to represent group resource" do
    before do
      @group = OmfEc::Group.new('bob', unique: false)
      @g_b = OmfEc::Group.new('g_b', unique: false)
    end

    it "must init default context related arrasy" do
      @group.net_ifs.must_equal []
      @group.members.must_equal []
      @group.app_contexts.must_equal []
    end

    it "must be capable of adding existing resources to group" do
      @group.add_resource(['r1', 'r2'])

      OmfEc.experiment.stubs(:groups).returns([@g_b])

      @group.add_resource('g_b')
    end

    it "must be capable of creating new resources and add them to group" do
      @group.create_resource('r1', { type: :test, p1: 'bob' })
    end

    it "must create new group context when calling resources" do
      @group.resources.must_be_kind_of OmfEc::Context::GroupContext
    end

    it "must be capable of associating pubsub topic instances" do
      t = mock
      @group.associate_topic(t)
      @group.topic.must_equal t

      @group.associate_resource_topic('bob', t)
      @group.resource_topic('bob').must_equal t
    end
  end
end

