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
    @message = @comm.request_message([:bob])
  end

  describe "when topic message object initialised" do
    include EM::MiniTest::Spec

    it "must be able to publish to a topic" do
      Blather::Client.stub :new, @client do
        published = Blather::XMPPNode.parse(published_xml)
        write_callback = proc do |event|
          event.must_be_kind_of Blather::Stanza::PubSub::Publish
          event.node.must_equal @topic.id
          published.id = event.id
          @client.receive_data published
        end
        @client.stub :write, write_callback do
          @message.publish(@topic.id) do |event|
            event.must_equal published
            done!
          end
        end
      end
      wait!
    end

  end

  describe "when message with same context id arrived " do
    include EM::MiniTest::Spec

    it "must react to omf created message" do
      Blather::Client.stub :new, @client do
        omf_create = @comm.create_message { |v| v.property('type', 'engine') }
        omf_create.body.stub :context_id, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
          omf_created = Blather::XMPPNode.parse(omf_created_xml)
          @client.receive_data omf_created
          omf_create.on_inform_created do |n|
            n.context_id.must_equal "bf840fe9-c176-4fae-b7de-6fc27f183f76"
            n.must_equal Message.parse(omf_created.items.first.payload)
            done!
          end
        end
      end
      wait!
    end

    it "must react to omf status message" do
      Blather::Client.stub :new, @client do
        omf_request = @comm.request_message { |v| v.property('bob') }
        omf_request.body.stub :context_id, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
          omf_status = Blather::XMPPNode.parse(omf_status_xml)
          @client.receive_data omf_status
          omf_request.on_inform_status do |n|
            n.context_id.must_equal "bf840fe9-c176-4fae-b7de-6fc27f183f76"
            n.must_equal Message.parse(omf_status.items.first.payload)
            done!
          end
        end
      end
      wait!
    end

    it "must react to omf release message" do
      Blather::Client.stub :new, @client do
        omf_release = @comm.release_message { |v| v.property('resource_id', '100') }
        omf_release.body.stub :context_id, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
          omf_released = Blather::XMPPNode.parse(omf_released_xml)
          @client.receive_data omf_released
          omf_release.on_inform_released do |n|
            n.context_id.must_equal "bf840fe9-c176-4fae-b7de-6fc27f183f76"
            n.must_equal Message.parse(omf_released.items.first.payload)
            done!
          end
        end
      end
      wait!
    end

    it "must react to omf failed message" do
      Blather::Client.stub :new, @client do
        omf_create = @comm.create_message { |v| v.property('type', 'engine') }
        omf_create.body.stub :context_id, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
          omf_failed = Blather::XMPPNode.parse(omf_failed_xml)
          @client.receive_data omf_failed
          omf_create.on_inform_failed do |n|
            n.context_id.must_equal "bf840fe9-c176-4fae-b7de-6fc27f183f76"
            n.must_equal Message.parse(omf_failed.items.first.payload)
            done!
          end
        end
      end
      wait!
    end
  end
end
