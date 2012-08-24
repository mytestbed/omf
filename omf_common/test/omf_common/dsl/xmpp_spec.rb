require 'test_helper'
require 'em/minitest/spec'

describe OmfCommon::DSL::Xmpp do
  before do
    @client = Blather::Client.new
    @stream = MiniTest::Mock.new
    @stream.expect(:send, true, [Blather::Stanza])
    @client.post_init @stream, Blather::JID.new('n@d/r')
    @xmpp = Class.new { include OmfCommon::DSL::Xmpp }.new
  end

  describe "when communicating to xmpp server (via mocking)" do
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

    it "must be able to subscribe" do
      Blather::Client.stub :new, @client do
        @stream.expect(:send, true, [Blather::Stanza::PubSub::Subscribe])
        @xmpp.subscribe 'xmpp_topic' do |event|
          true
        end
        @stream.verify
      end
    end

    it "must be able to create topic" do
      Blather::Client.stub :new, @client do
        @stream.expect(:send, true, [Blather::Stanza::PubSub::Create])
        @xmpp.create_topic 'xmpp_topic' do |event|
          true
        end
        @stream.verify
      end
    end

    it "must be able to delete topic" do
      Blather::Client.stub :new, @client do
        @stream.expect(:send, true, [Blather::Stanza::PubSubOwner::Delete])
        @xmpp.delete_topic 'xmpp_topic' do |event|
          true
        end
        @stream.verify
      end
    end

    it "must be able to list affiliations (owned pubsub nodes)" do
      Blather::Client.stub :new, @client do
        @stream.expect(:send, true, [Blather::Stanza::PubSub::Affiliations])
        @xmpp.affiliations do |event|
          true
        end
        @stream.verify
      end
    end

    it "must be able to publish if message is valid" do
      Blather::Client.stub :new, @client do
        @stream.expect(:send, true, [Blather::Stanza::PubSub::Publish])
        @xmpp.publish 'xmpp_topic', Message.create {|v| v.property('type', 'test')} do |event|
          true
        end
        proc { @xmpp.publish 'xmpp_topic', Message.inform {|v| v.element('blah', 'blah')} }.must_raise StandardError
        @stream.verify
      end
    end

    it "must be able to unsubscribe" do
      Blather::Client.stub :new, @client do
        @stream.expect(:send, true, [Blather::Stanza::PubSub::Subscriptions])
        @xmpp.unsubscribe
        @stream.verify
      end
    end

    it "must be able to add a topic event handler" do
      Blather::Client.stub :new, @client do
        @xmpp.topic_event { true }
        @stream.verify
      end
    end
  end

  describe "when omf message related methods" do
    it "must generate omf create xml fragment" do
      m1 = @xmpp.create_message([type: 'engine'])
      m2 = @xmpp.create_message do |v|
        v.property('type', 'test')
      end
      m1.must_equal m2
      m1.name.must_equal 'create'
      m1.to_xml.must_match /<property key="type">engine<\/property>/
    end

    it "must generate omf configure xml fragment" do
      m1 = @xmpp.configure_message([throttle: 50])
      m2 = @xmpp.configure_message do |v|
        v.property('throttle', 50)
      end
      m1.must_equal m2
      m1.name.must_equal 'configure'
      m1.to_xml.must_match /<property key="throttle">50<\/property>/
    end

    it "must generate omf inform xml fragment" do
      m1 = @xmpp.inform_message([inform_type: 'CREATED'])
      m2 = @xmpp.inform_message do |v|
        v.property('inform_type', 'test')
      end
      m1.must_equal m2
      m1.name.must_equal 'inform'
      m1.to_xml.must_match /<property key="inform_type">CREATED<\/property>/
    end

    it "must generate omf release xml fragment" do
      m1 = @xmpp.release_message([resource_id: 100])
      m2 = @xmpp.release_message do |v|
        v.property('resource_id', 100)
      end
      m1.must_equal m2
      m1.name.must_equal 'release'
      m1.to_xml.must_match /<property key="resource_id">100<\/property>/
    end

    it "must generate omf request xml fragment" do
      m1 = @xmpp.request_message([:max_rpm, {:provider => {country: 'japan'}}, :max_power])
      m2 = @xmpp.request_message do |v|
        v.property('max_rpm')
        v.property('provider') do |p|
          p.element('country', 'japan')
        end
        v.property('max_power')
      end
      m1.must_equal m2
      m1.name.must_equal 'request'
      m1.to_xml.must_match /<property key="max_rpm"\/>/
      m1.to_xml.must_match /<property key="provider">/
      m1.to_xml.must_match /<country>japan<\/country>/
      m1.to_xml.must_match /<property key="max_power"\/>/
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
end

