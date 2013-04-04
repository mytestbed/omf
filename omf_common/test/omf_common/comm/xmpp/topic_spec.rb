require 'fixture/pubsub'
require 'em/minitest/spec'

require 'omf_common/comm/xmpp/topic'

describe OmfCommon::Comm::XMPP::Topic do
  before do
    @client = Blather::Client.new
    @stream = MiniTest::Mock.new
    @stream.expect(:send, true, [Blather::Stanza])
    @client.post_init @stream, Blather::JID.new('n@d/r')
    @xmpp = OmfCommon::Comm::XMPP::Communicator.new

    OmfCommon.stub :comm, @xmpp do
      Blather::Client.stub :new, @client do
        @stream.expect(:send, true, [Blather::Stanza::PubSub::Create])
        @topic = OmfCommon::Comm::XMPP::Topic.create(:test_topic)
      end
    end
  end

  describe "when calling operation method" do
    it "must send create message" do
      OmfCommon.stub :comm, @xmpp do
        Blather::Client.stub :new, @client do
          published = Blather::XMPPNode.parse(published_xml)

          write_callback = proc do |event|
            event.must_be_kind_of Blather::Stanza::PubSub::Publish
            published.id = event.id
            @client.receive_data published
          end

          @client.stub :write, write_callback do
            @xmpp.stub :local_address, 'test_addr' do
              @topic.create(:bob, { hrn: 'bob' })
            end
          end
        end
      end
    end
  end

  describe "when informed message received" do
    include EM::MiniTest::Spec

    it "must react to omf created message" do
      OmfCommon.stub :comm, @xmpp do
        Blather::Client.stub :new, @client do
          omf_create = OmfCommon::Message.create(:create, { type: 'engine' })
          omf_create.stub :mid, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
            omf_created = Blather::XMPPNode.parse(omf_created_xml)
            @client.receive_data omf_created
            @topic.on_creation_ok(omf_create) do |n|
              OmfCommon::Message.parse(omf_created.items.first.payload) do |parsed_msg|
                n.stub :ts, parsed_msg.ts do
                  n.must_equal parsed_msg
                end
                done!
              end
            end
          end
        end
      end
      wait!
    end

    it "must react to omf status message" do
      OmfCommon.stub :comm, @xmpp do
        Blather::Client.stub :new, @client do
          omf_request = OmfCommon::Message.create(:request, [:bob])
          omf_request.stub :mid, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
            omf_status = Blather::XMPPNode.parse(omf_status_xml)
            @client.receive_data omf_status
            @topic.on_status(omf_request) do |n|
              OmfCommon::Message.parse(omf_status.items.first.payload) do |parsed_msg|
                n.stub :ts, parsed_msg.ts do
                  n.must_equal parsed_msg
                end
                done!
              end
            end
          end
        end
      end
      wait!
    end

    it "must react to omf release message" do
      OmfCommon.stub :comm, @xmpp do
        Blather::Client.stub :new, @client do
          omf_release = OmfCommon::Message.create(:release, nil, { res_id: '100' })
          omf_release.stub :mid, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
            omf_released = Blather::XMPPNode.parse(omf_released_xml)
            @client.receive_data omf_released
            @topic.on_released(omf_release) do |n|
              OmfCommon::Message.parse(omf_released.items.first.payload) do |parsed_msg|
                n.stub :ts, parsed_msg.ts do
                  n.must_equal parsed_msg
                end
                done!
              end
            end
          end
        end
      end
      wait!
    end

    it "must react to omf failed message" do
      OmfCommon.stub :comm, @xmpp do
        Blather::Client.stub :new, @client do
          omf_create = OmfCommon::Message.create(:create, { type: 'engine' })
          omf_create.stub :mid, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
            omf_failed = Blather::XMPPNode.parse(omf_failed_xml)
            @client.receive_data omf_failed
            @topic.on_creation_failed(omf_create) do |n|
              OmfCommon::Message.parse(omf_failed.items.first.payload) do |parsed_msg|
                n.stub :ts, parsed_msg.ts do
                  n.must_equal parsed_msg
                end
                done!
              end
            end
          end
        end
      end
      wait!
    end
  end
end
