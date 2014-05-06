require 'test_helper'
require 'omf_common/comm/amqp/amqp_communicator'

describe "Using AMQP communicator" do
  include EventedSpec::SpecHelper
  default_timeout 1.1

  before do
    @amqp_comm = OmfCommon::Comm::AMQP::Communicator.new
    OmfCommon::Eventloop.init(type: :em)
  end

  after do
    em do
      @amqp_comm.init(url: 'amqp://localhost')
      done(0.2)
    end
  end

  it "must allow you to connect" do
    @amqp_comm.on_connected do |c|
      c.must_be_kind_of OmfCommon::Comm::AMQP::Communicator
      c.conn_info[:proto].must_equal :amqp
      c.conn_info[:user].must_equal "guest"
    end
  end

  it "must construct topic address string" do
    @amqp_comm.on_connected do |c|
      c.string_to_topic_address('bob').must_equal "amqp://localhost/frcp.bob"
    end
  end

  it "must allow you to create a new pubsub topic" do
    @amqp_comm.on_connected do |c|
      c.create_topic('bob')
      OmfCommon::Comm::Topic[:bob].must_be_kind_of(OmfCommon::Comm::AMQP::Topic)
    end
  end

  it "must allow you to delete a pubsub topic" do
  end
end
