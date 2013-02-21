require 'test_helper'
require 'omf_ec/group'

describe OmfEc::Group do
  describe "when initialised" do
    it "must be generate unique id if :unique option is on" do
      OmfEc.stub :subscribe_and_monitor, true do
        OmfEc::Group.new('bob').id.wont_equal 'bob'
      end
    end

    it "must use name as id if :unique option is off" do
      OmfEc.stub :subscribe_and_monitor, true do
        OmfEc::Group.new('bob', unique: false).id.must_equal 'bob'
      end
    end
  end

  describe "when used to represent group resource" do
    before do
      @comm = MiniTest::Mock.new
      OmfEc.stub :subscribe_and_monitor, true do
        @group = OmfEc::Group.new('bob', unique: false)
      end
    end

    it "must init default context related arrasy" do
      @group.net_ifs.must_equal []
      @group.members.must_equal []
      @group.app_contexts.must_equal []
    end

    it "must be capable of adding existing resources to group" do
      skip
      OmfCommon.stub :comm, @comm do
        @comm.expect(:subscribe, true, [Array])
        @group.add_resource(['r1', 'r2'])
        @comm.verify
      end
    end

    it "must be capable of creating new resources and add them to group" do
      skip
      OmfCommon.stub :comm, @comm do
        @comm.expect(:subscribe, true, [String])
        @comm.expect(:create_topic, true, [String])
        @group.create_resource('r1', { type: :test, p1: 'bob' })
        @comm.verify
      end
    end

    it "must create new group context when calling resources" do
      @group.resources.must_be_kind_of OmfEc::Context::GroupContext
    end
  end
end

