require 'test_helper'
require 'fixture/pubsub'
require 'em/minitest/spec'

require 'omf_common/comm/xmpp/communicator'

describe OmfCommon::Comm::XMPP::Communicator do
  before do
    @client = Blather::Client.new
    @stream = MiniTest::Mock.new
    @stream.expect(:send, true, [Blather::Stanza])
    @client.post_init @stream, Blather::JID.new('bob@example.com')
    @xmpp = OmfCommon::Comm::XMPP::Communicator.new
  end

  describe "when communicating to xmpp server (via mocking)" do
    include EM::MiniTest::Spec

    it "must be able to connect and tigger on_connected callbacks" do
      Blather::Client.stub :new, @client do
        @xmpp.jid.inspect.must_equal "bob@example.com"

        @xmpp.on_connected do |communicator|
          communicator.must_be_kind_of OmfCommon::Comm::XMPP::Communicator
        end
        @stream.verify
      end
    end

    it "must be able to disconnect" do
      Blather::Client.stub :new, @client do
        @stream.expect(:close_connection_after_writing, true)
        @xmpp.disconnect
        @stream.verify
      end
    end

    it "must be able to subscribe & trigger callback when subscribed" do
      skip
      Blather::Client.stub :new, @client do
        subscription = Blather::XMPPNode.parse(subscription_xml)
        write_callback = proc do |event|
          event.must_be_kind_of Blather::Stanza::PubSub::Subscribe
          subscription.id = event.id
          @client.receive_data subscription
        end
        @client.stub :write, write_callback do
          @xmpp.subscribe('xmpp_topic') do |topic|
            topic.must_be_kind_of OmfCommon::Comm::XMPP::Topic
            topic.id.must_equal :xmpp_topic
            done!
          end
        end
      end
      wait!
    end

    it "must be able to create topic & trigger callback when created" do
      Blather::Client.stub :new, @client do
        OmfCommon.stub :comm, @xmpp do
          @stream.expect(:send, true, [Blather::Stanza])
          @xmpp.create_topic('xmpp_topic').must_be_kind_of OmfCommon::Comm::XMPP::Topic
        end
      end
    end

    it "must be able to delete topic & trigger callback when topic deleted" do
      Blather::Client.stub :new, @client do
        deleted = Blather::XMPPNode.parse(fabulous_xmpp_empty_success_xml)
        write_callback = proc do |event|
          event.must_be_kind_of Blather::Stanza::PubSubOwner::Delete
          deleted.id = event.id
          @client.receive_data deleted
        end
        @client.stub :write, write_callback do
          @xmpp.delete_topic('xmpp_topic') do |stanza|
            done!
          end
        end
      end
      wait!
    end

    it "must be able to list affiliations (owned pubsub nodes) & react if received" do
      Blather::Client.stub :new, @client do
        affiliations = Blather::XMPPNode.parse(affiliations_xml)
        write_callback = proc do |event|
          event.must_be_kind_of Blather::Stanza::PubSub::Affiliations
          affiliations.id = event.id
          @client.receive_data affiliations
        end
        @client.stub :write, write_callback do
          @xmpp.affiliations { |event| event[:owner].must_equal %w(node1 node2); done! }
        end
      end
      wait!
    end

    it "must be able to publish if message is valid" do
      Blather::Client.stub :new, @client do
        @stream.expect(:send, true, [Blather::Stanza::PubSub::Publish])
        @xmpp.publish 'xmpp_topic', OmfCommon::Message.create(:create, { type: 'test' })
        proc { @xmpp.publish 'xmpp_topic', OmfCommon::Message.create(:inform, nil, { blah: 'blah' })}.must_raise StandardError
        @stream.verify
      end
    end

    it "must trigger callback when item published" do
      Blather::Client.stub :new, @client do
        published = Blather::XMPPNode.parse(published_xml)
        write_callback = proc do |event|
          event.must_be_kind_of Blather::Stanza::PubSub::Publish
          published.id = event.id
          @client.receive_data published
        end
        @client.stub :write, write_callback do
          @xmpp.publish 'xmpp_topic', OmfCommon::Message.create(:create, { type: 'test' }) do |event|
            event.must_equal published
            done!
          end
        end
      end
      wait!
    end

    it "must be able to unsubscribe" do
      Blather::Client.stub :new, @client do
        @stream.expect(:send, true, [Blather::Stanza::PubSub::Subscriptions])
        @xmpp.unsubscribe
        @stream.verify
      end
    end

    it "must trigger callback when unsubscribed (all topics)" do
      Blather::Client.stub :new, @client do
        2.times do
          @stream.expect(:send, true, [Blather::Stanza])
        end

        subscriptions = Blather::XMPPNode.parse(subscriptions_xml)
        write_callback = proc do |event|
          event.must_be_kind_of Blather::Stanza::PubSub::Subscriptions
          subscriptions.id = event.id
          @client.receive_data subscriptions
        end
        @client.stub :write, write_callback do
          @xmpp.unsubscribe
        end
        @stream.verify
      end
    end

    it "must be able to add a topic event handler" do
      Blather::Client.stub :new, @client do
        @xmpp.topic_event
        @stream.verify
      end
    end
  end

  describe "when omf message related methods" do
    it "must generate omf create xml fragment" do
      skip
      m1 = @xmpp.create_message([type: 'engine'])
      m2 = @xmpp.create_message do |v|
        v.property('type', 'engine')
      end
      m1.must_be_kind_of OmfCommon::TopicMessage
      m2.must_be_kind_of OmfCommon::TopicMessage
      m1.body.name.must_equal 'create'
      m1.body.to_xml.must_match /<property key="type" type="string">engine<\/property>/
      m2.body.to_xml.must_match /<property key="type" type="string">engine<\/property>/
    end

    it "must generate omf configure xml fragment" do
      skip
      m1 = @xmpp.configure_message([throttle: 50])
      m2 = @xmpp.configure_message do |v|
        v.property('throttle', 50)
      end
      m1.must_be_kind_of OmfCommon::TopicMessage
      m2.must_be_kind_of OmfCommon::TopicMessage
      m1.body.name.must_equal 'configure'
      m1.body.to_xml.must_match /<property key="throttle" type="integer">50<\/property>/
      m2.body.to_xml.must_match /<property key="throttle" type="integer">50<\/property>/
    end

    it "must generate omf inform xml fragment" do
      skip
      m1 = @xmpp.inform_message([inform_type: 'CREATION_OK'])
      m2 = @xmpp.inform_message do |v|
        v.property('inform_type', 'CREATION_OK')
      end
      m1.must_be_kind_of OmfCommon::TopicMessage
      m2.must_be_kind_of OmfCommon::TopicMessage
      m1.body.name.must_equal 'inform'
      m1.body.to_xml.must_match /<property key="inform_type" type="string">CREATION_OK<\/property>/
      m2.body.to_xml.must_match /<property key="inform_type" type="string">CREATION_OK<\/property>/
    end

    it "must generate omf release xml fragment" do
      skip
      m1 = @xmpp.release_message([resource_id: 100])
      m2 = @xmpp.release_message do |v|
        v.property('resource_id', 100)
      end
      m1.must_be_kind_of OmfCommon::TopicMessage
      m2.must_be_kind_of OmfCommon::TopicMessage
      m1.body.name.must_equal 'release'
      m1.body.to_xml.must_match /<property key="resource_id" type="integer">100<\/property>/
      m2.body.to_xml.must_match /<property key="resource_id" type="integer">100<\/property>/
    end

    it "must generate omf request xml fragment" do
      skip
      m1 = @xmpp.request_message([:max_rpm, {:provider => {country: 'japan'}}, :max_power])
      m2 = @xmpp.request_message do |v|
        v.property('max_rpm')
        v.property('provider', { country: 'japan' })
        v.property('max_power')
      end
      m1.must_be_kind_of OmfCommon::TopicMessage
      m2.must_be_kind_of OmfCommon::TopicMessage
      m1.body.name.must_equal 'request'
      m1.body.to_xml.must_match /<property key="max_rpm"\/>/
      m1.body.to_xml.must_match /<property key="provider" type="hash">/
      m2.body.to_xml.must_match /<property key="provider" type="hash">/
      m1.body.to_xml.must_match /<country type="string">japan<\/country>/
      m2.body.to_xml.must_match /<country type="string">japan<\/country>/
      m1.body.to_xml.must_match /<property key="max_power"\/>/
    end
  end

  describe "when use event machine style method" do
    include EM::MiniTest::Spec

    it "must accept these methods and forward to event machine" do
      skip
      OmfCommon.eventloop.after(0.05) { done! }
      OmfCommon.eventloop.every(0.05) { done! }
      wait!
    end
  end
end

