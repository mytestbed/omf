# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_ec/group'

describe OmfEc::Group do
  before do
    OmfEc.stubs(:subscribe_and_monitor)
    OmfEc::Group.any_instance.stubs(:address).returns("xmpp://g@bob.com")
  end

  after do
    OmfEc.unstub(:subscribe_and_monitor)
    OmfEc::Group.any_instance.unstub(:address)
  end

  describe "when used to represent group resource" do
    before do
      @group = OmfEc::Group.new('bob')
      @g_b = OmfEc::Group.new('g_b')
    end

    it "must init default context related variables" do
      @group.net_ifs.must_equal([])
      @group.members.must_equal({})
      @group.app_contexts.must_equal([])
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

