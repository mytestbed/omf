require 'test_helper'
require 'fixture/pubsub'
require 'em/minitest/spec'

include OmfCommon

describe OmfCommon::Topic do
  before do
    @client = Blather::Client.new
    @stream = MiniTest::Mock.new
    @stream.expect(:send, true, [Blather::Stanza])
    @client.post_init @stream, Blather::JID.new('n@d/r')
    @comm = Class.new { include OmfCommon::DSL::Xmpp }.new
    @topic = @comm.get_topic('mclaren')
  end

  describe "when topic object initialised" do
    include EM::MiniTest::Spec

    it "must subscribe" do
      Blather::Client.stub :new, @client do
        subscription = Blather::XMPPNode.parse(subscription_xml)
        write_callback = proc do |event|
          event.must_be_kind_of Blather::Stanza::PubSub::Subscribe
          event.node.must_equal 'mclaren'
          subscription.id = event.id
          subscription.node = event.node
          @client.receive_data subscription
        end
        @client.stub :write, write_callback do
          @topic.subscribe do |e|
            e.must_equal subscription
            e.node.must_equal 'mclaren'
            done!
          end
        end
      end
      wait!
    end

    it "must react when message arrived" do
      Blather::Client.stub :new, @client do
        omf_status = Blather::XMPPNode.parse(omf_status_xml)
        @client.receive_data omf_status
        @topic.on_message do |n|
          n.must_equal Message.parse(omf_status.items.first.payload)
          done!
        end

        invalid_topic = @comm.get_topic('bob')
        invalid_topic.on_message do |n|
          raise 'Wont come here'
        end
      end
      wait!
    end

    it "must react when certain messages arrived, specified by guards" do
      Blather::Client.stub :new, @client do
        omf_status = Blather::XMPPNode.parse(omf_status_xml)
        @client.receive_data omf_status
        @topic.on_message proc { |message| message.context_id == 'bob' } do |n|
          raise 'Wont come here'
        end

        @topic.on_message proc { |message| message.context_id == "bf840fe9-c176-4fae-b7de-6fc27f183f76" } do |n|
          n.must_equal Message.parse(omf_status.items.first.payload)
          n.context_id.must_equal "bf840fe9-c176-4fae-b7de-6fc27f183f76"
          done!
        end
      end
      wait!
    end
  end
end
