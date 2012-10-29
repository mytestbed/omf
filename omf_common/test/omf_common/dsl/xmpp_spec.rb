require 'test_helper'
require 'fixture/pubsub'
require 'em/minitest/spec'

describe OmfCommon::DSL::Xmpp do
  before do
    @client = Blather::Client.new
    @stream = MiniTest::Mock.new
    @stream.expect(:send, true, [Blather::Stanza])
    @client.post_init @stream, Blather::JID.new('n@d/r')
    @xmpp = OmfCommon::Comm.new(:xmpp)
  end

  describe "when communicating to xmpp server (via mocking)" do
    include EM::MiniTest::Spec

    it "must be able to connect" do
      Blather::Stream::Client.stub(:start, @client) do
        Blather::Client.stub :new, @client do
          @xmpp.jid.inspect.must_equal "n@d/r"
          @xmpp.connect('bob', 'pw', 'example.com')
          @xmpp.jid.inspect.must_equal "bob@example.com"
        end
      end
    end

    it "must be able to disconnect" do
      Blather::Stream::Client.stub(:start, @client) do
        Blather::Client.stub :new, @client do
          @stream.expect(:close_connection_after_writing, true)
          @xmpp.disconnect
          @stream.verify
        end
      end
    end

    it "must be able to subscribe & trigger callback when subscribed" do
      Blather::Client.stub :new, @client do
        subscription = Blather::XMPPNode.parse(subscription_xml)
        write_callback = proc do |event|
          event.must_be_kind_of Blather::Stanza::PubSub::Subscribe
          subscription.id = event.id
          @client.receive_data subscription
        end
        @client.stub :write, write_callback do
          @xmpp.subscribe('xmpp_topic') { |e| e.must_equal subscription; done! }
        end
      end
      wait!
    end

    it "must be able to create topic & trigger callback when created" do
      Blather::Client.stub :new, @client do
        created = Blather::XMPPNode.parse(created_xml)
        write_callback = proc do |event|
          event.must_be_kind_of Blather::Stanza::PubSub::Create
          created.id = event.id
          @client.receive_data created
        end
        @client.stub :write, write_callback do
          @xmpp.create_topic('xmpp_topic') { |event| event.must_equal created; done! }
        end
      end
      wait!
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
          @xmpp.delete_topic('xmpp_topic') { |event| event.must_equal deleted; done! }
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
        @xmpp.publish 'xmpp_topic', Message.create {|v| v.property('type', 'test')}
        proc { @xmpp.publish 'xmpp_topic', Message.inform {|v| v.element('blah', 'blah')} }.must_raise StandardError
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
          @xmpp.publish 'xmpp_topic', Message.create {|v| v.property('type', 'test')} do |event|
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
      m1 = @xmpp.configure_message([throttle: 50])
      m2 = @xmpp.configure_message do |v|
        v.property('throttle', 50)
      end
      m1.must_be_kind_of OmfCommon::TopicMessage
      m2.must_be_kind_of OmfCommon::TopicMessage
      m1.body.name.must_equal 'configure'
      m1.body.to_xml.must_match /<property key="throttle" type="fixnum">50<\/property>/
      m2.body.to_xml.must_match /<property key="throttle" type="fixnum">50<\/property>/
    end

    it "must generate omf inform xml fragment" do
      m1 = @xmpp.inform_message([inform_type: 'CREATED'])
      m2 = @xmpp.inform_message do |v|
        v.property('inform_type', 'CREATED')
      end
      m1.must_be_kind_of OmfCommon::TopicMessage
      m2.must_be_kind_of OmfCommon::TopicMessage
      m1.body.name.must_equal 'inform'
      m1.body.to_xml.must_match /<property key="inform_type" type="string">CREATED<\/property>/
      m2.body.to_xml.must_match /<property key="inform_type" type="string">CREATED<\/property>/
    end

    it "must generate omf release xml fragment" do
      m1 = @xmpp.release_message([resource_id: 100])
      m2 = @xmpp.release_message do |v|
        v.property('resource_id', 100)
      end
      m1.must_be_kind_of OmfCommon::TopicMessage
      m2.must_be_kind_of OmfCommon::TopicMessage
      m1.body.name.must_equal 'release'
      m1.body.to_xml.must_match /<property key="resource_id" type="fixnum">100<\/property>/
      m2.body.to_xml.must_match /<property key="resource_id" type="fixnum">100<\/property>/
    end

    it "must generate omf request xml fragment" do
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

  describe "when informed message received" do
    include EM::MiniTest::Spec

    it "must react to omf created message" do
      Blather::Client.stub :new, @client do
        omf_create = OmfCommon::Message.create { |v| v.property('type', 'engine') }
        omf_create.stub :context_id, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
          omf_created = Blather::XMPPNode.parse(omf_created_xml)
          @client.receive_data omf_created
          @xmpp.on_created_message(omf_create) do |n|
            n.must_equal Message.parse(omf_created.items.first.payload)
            done!
          end
        end
      end
      wait!
    end

    it "must react to omf status message" do
      Blather::Client.stub :new, @client do
        omf_request = OmfCommon::Message.request { |v| v.property('bob') }
        omf_request.stub :context_id, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
          omf_status = Blather::XMPPNode.parse(omf_status_xml)
          @client.receive_data omf_status
          @xmpp.on_status_message(omf_request) do |n|
            n.must_equal Message.parse(omf_status.items.first.payload)
            done!
          end
        end
      end
      wait!
    end

    it "must react to omf release message" do
      Blather::Client.stub :new, @client do
        omf_release = OmfCommon::Message.release { |v| v.property('resource_id', '100') }
        omf_release.stub :context_id, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
          omf_released = Blather::XMPPNode.parse(omf_released_xml)
          @client.receive_data omf_released
          @xmpp.on_released_message(omf_release) do |n|
            n.must_equal Message.parse(omf_released.items.first.payload)
            done!
          end
        end
      end
      wait!
    end

    it "must react to omf failed message" do
      Blather::Client.stub :new, @client do
        omf_create = OmfCommon::Message.create { |v| v.property('type', 'engine') }
        omf_create.stub :context_id, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
          omf_failed = Blather::XMPPNode.parse(omf_failed_xml)
          @client.receive_data omf_failed
          @xmpp.on_failed_message(omf_create) do |n|
            n.must_equal Message.parse(omf_failed.items.first.payload)
            done!
          end
        end
      end
      wait!
    end
  end

  describe "when use event machine style method" do
    include EM::MiniTest::Spec

    it "must accept these methods and forward to event machine" do
      @xmpp.add_timer(0.05) { done! }
      @xmpp.add_periodic_timer(0.05) { done! }
      wait!
    end
  end

  describe "when asked to get a topic object" do
    it "must return a topic object (pubsub topic) or nil if not found" do
      topic = @xmpp.get_topic('xmpp_topic')
      topic.must_be_kind_of OmfCommon::Topic
      topic.comm.must_equal @xmpp
    end
  end
end

