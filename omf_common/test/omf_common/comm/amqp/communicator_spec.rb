require 'test_helper'
require 'omf_common/comm/amqp/amqp_communicator'

describe "Using AMQP communicator" do
  include EventedSpec::SpecHelper
  default_timeout 1.1

  before do
    @amqp_comm = OmfCommon::Comm::AMQP::Communicator.new
    OmfCommon::Eventloop.init(type: :em)
    OmfCommon.stubs(:comm).returns(@amqp_comm)
  end

  after do
    em do
      @amqp_comm.init(url: 'amqp://localhost')
    end
  end

  it "must allow you to connect" do
    @amqp_comm.on_connected do |c|
      assert_kind_of OmfCommon::Comm::AMQP::Communicator, c
      assert_equal :amqp, c.conn_info[:proto]
      assert_equal "guest", c.conn_info[:user]
      done
    end
  end

  it "must construct topic address string" do
    @amqp_comm.on_connected do |c|
      t_name = SecureRandom.uuid
      assert_equal "amqp://localhost/frcp.#{t_name}", c.string_to_topic_address(t_name)
      done
    end
  end

  it "must allow you to create a new pubsub topic" do
    @amqp_comm.on_connected do |c|
      t_name = SecureRandom.uuid.to_sym
      c.create_topic(t_name)
      assert_kind_of OmfCommon::Comm::AMQP::Topic, OmfCommon::Comm::Topic[t_name]
      done
    end
  end

  it "must allow you to delete a pubsub topic" do
    skip
  end
end
