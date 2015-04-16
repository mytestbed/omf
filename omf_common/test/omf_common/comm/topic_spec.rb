# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_common/message/json/json_message'

describe OmfCommon::Comm::Topic do
  describe "when using factory method to initialise" do
    before  do
      @topic = OmfCommon::Comm::Topic.create(:bob)
    end

    it "must add it to the instance list" do
      OmfCommon::Comm::Topic[:bob].must_equal @topic
    end

    it "must have interface for its address" do
      lambda { @topic.address }.must_raise NotImplementedError
    end

    it "must have interface for on_subscribed handler" do
      lambda { @topic.on_subscribed }.must_raise NotImplementedError
    end

    it "must have error? returns false by default" do
      @topic.error?.must_equal false
    end

    it "must have interface for timer :after" do
      OmfCommon::Eventloop.init(type: :em)

      @topic.after(5, & lambda {})

      OmfCommon.eventloop.run do
        @topic.after(0.1) do |t|
          t.must_equal @topic
          OmfCommon.eventloop.stop
        end
      end

      OmfCommon::Eventloop.reset
    end
  end

  describe "when interact with topic instance" do
    before do
      @comm = mock

      # TODO Again, can not create an abstract topic without init a message
      OmfCommon::Message.init(type: :json)

      OmfCommon.stubs(:comm).returns(@comm)
      @topic = OmfCommon::Comm::Topic.create(:bob)
      @comm.stubs(:local_address).returns(:bob_address)
      @comm.stubs(:create_topic).returns(@topic)
    end

    after do
      OmfCommon::Comm.reset
      OmfCommon::Message.reset
      OmfCommon.unstub(:comm)
      #OmfCommon::Message::XML::Message.any_instance.unstub(:mid)
      OmfCommon::Message::Json::Message.any_instance.unstub(:mid)
    end

    it "must create and send frcp create message" do
      @topic.create(:rtype).must_equal @topic
    end

    it "must create and send frcp configure message" do
      @topic.configure(attr: 'value').must_equal @topic
    end

    it "must create and send frcp request message" do
      @topic.request([:attr]).must_equal @topic
    end

    it "must create and send frcp inform message" do
      @topic.inform('CREATION.OK', attr: 'value').must_equal @topic
    end

    it "must create and send frcp inform message" do
      lambda { @topic.release(:bob) }.must_raise ArgumentError
      @topic.release(@topic)
    end

    it "must create different types of message handlers" do
      @topic.class_eval do
        define_method(:handlers, &(lambda { @handlers }))
      end

      [:message, :inform].each do |name|
        m_name = "on_#{name}"
        # No callback block given shall fail
        lambda { @topic.send(m_name) }.must_raise ArgumentError
        cbk = proc {}
        @topic.send(m_name, &(cbk))
        @topic.handlers[name].values.must_include cbk
      end

      @topic.class_eval do
        undef_method(:handlers)
      end
    end

    it "must send a message and register callbacks" do
      @topic.class_eval do
        define_method(:context2cbk, &(lambda { @context2cbk }))
        define_method(:_send_message_public) do |*args|
          _send_message(*args)
        end
      end

      cbk = proc { 'called' }
      msg = mock
      msg.stubs(:mid).returns(:bob_id)

      @topic._send_message_public(msg, cbk)

      h = @topic.context2cbk['bob_id']
      h.must_be_kind_of Hash
      h[:block].call.must_equal 'called'

      @topic.class_eval do
        undef_method(:context2cbk)
        undef_method(:_send_message_public)
      end
    end

    it "must process incoming messages and trigger registered callbacks" do
      @topic.class_eval do
        define_method(:handlers, &(lambda { @handlers }))
        define_method(:context2cbk, &(lambda { @context2cbk }))
        define_method(:on_incoming_message_public) do |*args|
          on_incoming_message(*args)
        end
      end

      msg = mock
      msg.stubs(:operation).returns(:inform)
      msg.stubs(:itype).with(:ruby).returns('creation_ok')
      msg.stubs(:cid).returns(:bob_id)

      OmfCommon::Message::Json::Message.any_instance.stubs(:mid).returns(:bob_id)

      cbk_called = [false, false, false, false]

      @topic.create(:rtype) do |reply_msg|
        cbk_called[0] = true
        reply_msg.cid.must_equal :bob_id
      end

      @topic.on_inform do |incoming_msg|
        cbk_called[1] = true
        incoming_msg.cid.must_equal :bob_id
      end

      @topic.on_message do |incoming_msg|
        cbk_called[2] = true
        incoming_msg.cid.must_equal :bob_id
      end

      @topic.on_creation_ok do |incoming_msg|
        cbk_called[3] = true
        incoming_msg.cid.must_equal :bob_id
      end

      @topic.on_incoming_message_public(msg)

      msg.stubs(:itype).returns(:status)

      @topic.on_incoming_message_public(msg)

      cbk_called[0].must_equal true
      cbk_called[1].must_equal true
      cbk_called[2].must_equal true
      cbk_called[3].must_equal true

      @topic.class_eval do
        undef_method(:context2cbk)
        undef_method(:handlers)
        undef_method(:on_incoming_message_public)
      end
    end
  end
end
