#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
require 'omf_common/comm/xmpp/communicator'

describe "Using XMPP communicator" do
  include EventedSpec::SpecHelper

  # XMPP requires more time
  default_timeout 10.1

  before do
    @xmpp_comm = OmfCommon::Comm::XMPP::Communicator.new
    OmfCommon::Eventloop.init(type: :em)
    OmfCommon.stubs(:comm).returns(@xmpp_comm)
  end

  after do
    em do
      @xmpp_comm.init(url: 'xmpp://srv.mytestbed.net')
    end
  end

  it "must allow you to connect" do
    @xmpp_comm.on_connected do |c|
      assert_equal :xmpp, c.conn_info[:proto]
      assert_match /#{Socket.gethostname}/, c.conn_info[:user]
      assert_kind_of OmfCommon::Comm::XMPP::Communicator, c
      done
    end
  end

  it "must construct topic address string" do
    @xmpp_comm.on_connected do |c|
      t_name = SecureRandom.uuid
      # TODO This format is different to AMQP
      assert_match /xmpp:\/\/#{t_name}@/, c.string_to_topic_address(t_name)
      done
    end
  end

  it "must allow you to create a new pubsub topic" do
    @xmpp_comm.on_connected do |c|
      t_name = SecureRandom.uuid.to_sym
      c.create_topic(t_name)
      assert_kind_of OmfCommon::Comm::XMPP::Topic, OmfCommon::Comm::Topic[t_name]
      done
    end
  end
end

#  describe "when communicating to xmpp server (via mocking)" do
#    #include EM::MiniTest::Spec
#
#    it "must be able to connect and tigger on_connected callbacks" do
#      skip
#      Blather::Client.stub :new, @client do
#        @xmpp.jid.to_s.must_equal "bob@example.com"
#
#        @xmpp.on_connected do |communicator|
#          communicator.must_be_kind_of OmfCommon::Comm::XMPP::Communicator
#        end
#        @stream.verify
#      end
#    end
#
#    it "must be able to disconnect" do
#      skip
#      Blather::Client.stub :new, @client do
#        @stream.expect(:close_connection_after_writing, true)
#        @xmpp.disconnect
#      end
#    end
#
#    it "must be able to subscribe & trigger callback when subscribed" do
#      skip
#      Blather::Client.stub :new, @client do
#        subscription = Blather::XMPPNode.parse(subscription_xml)
#        write_callback = proc do |event|
#          event.must_be_kind_of Blather::Stanza::PubSub::Subscribe
#          subscription.id = event.id
#          @client.receive_data subscription
#        end
#        @client.stub :write, write_callback do
#          @xmpp.subscribe('xmpp_topic') do |topic|
#            topic.must_be_kind_of OmfCommon::Comm::XMPP::Topic
#            topic.id.must_equal :xmpp_topic
#            done!
#          end
#        end
#      end
#      wait!
#    end
#
#    it "must be able to delete topic & trigger callback when topic deleted" do
#      skip
#      Blather::Client.stub :new, @client do
#        deleted = Blather::XMPPNode.parse(fabulous_xmpp_empty_success_xml)
#        write_callback = proc do |event|
#          event.must_be_kind_of Blather::Stanza::PubSubOwner::Delete
#          deleted.id = event.id
#          @client.receive_data deleted
#        end
#        @client.stub :write, write_callback do
#          @xmpp.delete_topic('xmpp_topic') do |stanza|
#            done!
#          end
#        end
#      end
#      wait!
#    end
#
#    it "must be able to list affiliations (owned pubsub nodes) & react if received" do
#      skip
#      Blather::Client.stub :new, @client do
#        affiliations = Blather::XMPPNode.parse(affiliations_xml)
#        write_callback = proc do |event|
#          event.must_be_kind_of Blather::Stanza::PubSub::Affiliations
#          affiliations.id = event.id
#          @client.receive_data affiliations
#        end
#        @client.stub :write, write_callback do
#          @xmpp.affiliations { |event| puts event[:owner]; event[:owner].must_equal %w(node1 node2); done! }
#        end
#      end
#      wait!
#    end
#
#    it "must be able to publish if message is valid" do
#      skip
#      Blather::Client.stub :new, @client do
#        @stream.expect(:send, true, [Blather::Stanza::PubSub::Publish])
#        @xmpp.publish 'xmpp_topic', OmfCommon::Message.create(:create, { type: 'test' })
#        proc { @xmpp.publish 'xmpp_topic', OmfCommon::Message.create(:inform, nil, { blah: 'blah' })}.must_raise StandardError
#        @stream.verify
#      end
#    end
#
#    it "must trigger callback when item published" do
#      skip
#      Blather::Client.stub :new, @client do
#        published = Blather::XMPPNode.parse(published_xml)
#        write_callback = proc do |event|
#          event.must_be_kind_of Blather::Stanza::PubSub::Publish
#          published.id = event.id
#          @client.receive_data published
#        end
#        @client.stub :write, write_callback do
#          @xmpp.publish 'xmpp_topic', OmfCommon::Message.create(:create, { type: 'test' }) do |event|
#            event.must_equal published
#            done!
#          end
#        end
#      end
#      wait!
#    end
#
#    it "must be able to unsubscribe" do
#      skip
#      Blather::Client.stub :new, @client do
#        @stream.expect(:send, true, [Blather::Stanza::PubSub::Subscriptions])
#        @xmpp.unsubscribe
#        @stream.verify
#      end
#    end
#
#    it "must trigger callback when unsubscribed (all topics)" do
#      skip
#      Blather::Client.stub :new, @client do
#        2.times do
#          @stream.expect(:send, true, [Blather::Stanza])
#        end
#
#        subscriptions = Blather::XMPPNode.parse(subscriptions_xml)
#        write_callback = proc do |event|
#          event.must_be_kind_of Blather::Stanza::PubSub::Subscriptions
#          subscriptions.id = event.id
#          @client.receive_data subscriptions
#        end
#        @client.stub :write, write_callback do
#          @xmpp.unsubscribe
#        end
#        @stream.verify
#      end
#    end
#
#    it "must be able to add a topic event handler" do
#      skip
#      Blather::Client.stub :new, @client do
#        @xmpp.topic_event
#        @stream.verify
#      end
#    end
#  end
#
#  describe "when omf message related methods" do
#    it "must generate omf create xml fragment" do
#      skip
#      m1 = @xmpp.create_message([type: 'engine'])
#      m2 = @xmpp.create_message do |v|
#        v.property('type', 'engine')
#      end
#      m1.must_be_kind_of OmfCommon::TopicMessage
#      m2.must_be_kind_of OmfCommon::TopicMessage
#      m1.body.name.must_equal 'create'
#      m1.body.marshall[1].must_match /<property key="type" type="string">engine<\/property>/
#      m2.body.marshall[1].must_match /<property key="type" type="string">engine<\/property>/
#    end
#
#    it "must generate omf configure xml fragment" do
#      skip
#      m1 = @xmpp.configure_message([throttle: 50])
#      m2 = @xmpp.configure_message do |v|
#        v.property('throttle', 50)
#      end
#      m1.must_be_kind_of OmfCommon::TopicMessage
#      m2.must_be_kind_of OmfCommon::TopicMessage
#      m1.body.name.must_equal 'configure'
#      m1.body.marshall[1].must_match /<property key="throttle" type="integer">50<\/property>/
#      m2.body.marshall[1].must_match /<property key="throttle" type="integer">50<\/property>/
#    end
#
#    it "must generate omf inform xml fragment" do
#      skip
#      m1 = @xmpp.inform_message([itype: 'CREATION.OK'])
#      m2 = @xmpp.inform_message do |v|
#        v.property('itype', 'CREATION.OK')
#      end
#      m1.must_be_kind_of OmfCommon::TopicMessage
#      m2.must_be_kind_of OmfCommon::TopicMessage
#      m1.body.name.must_equal 'inform'
#      m1.body.marshall[1].must_match /<property key="itype" type="string">CREATION.OK<\/property>/
#      m2.body.marshall[1].must_match /<property key="itype" type="string">CREATION.OK<\/property>/
#    end
#
#    it "must generate omf release xml fragment" do
#      skip
#      m1 = @xmpp.release_message([res_id: 100])
#      m2 = @xmpp.release_message do |v|
#        v.property('res_id', 100)
#      end
#      m1.must_be_kind_of OmfCommon::TopicMessage
#      m2.must_be_kind_of OmfCommon::TopicMessage
#      m1.body.name.must_equal 'release'
#      m1.body.marshall[1].must_match /<property key="res_id" type="integer">100<\/property>/
#      m2.body.marshall[1].must_match /<property key="res_id" type="integer">100<\/property>/
#    end
#
#    it "must generate omf request xml fragment" do
#      skip
#      m1 = @xmpp.request_message([:max_rpm, {:provider => {country: 'japan'}}, :max_power])
#      m2 = @xmpp.request_message do |v|
#        v.property('max_rpm')
#        v.property('provider', { country: 'japan' })
#        v.property('max_power')
#      end
#      m1.must_be_kind_of OmfCommon::TopicMessage
#      m2.must_be_kind_of OmfCommon::TopicMessage
#      m1.body.name.must_equal 'request'
#      m1.body.marshall[1].must_match /<property key="max_rpm"\/>/
#      m1.body.marshall[1].must_match /<property key="provider" type="hash">/
#      m2.body.marshall[1].must_match /<property key="provider" type="hash">/
#      m1.body.marshall[1].must_match /<country type="string">japan<\/country>/
#      m2.body.marshall[1].must_match /<country type="string">japan<\/country>/
#      m1.body.marshall[1].must_match /<property key="max_power"\/>/
#    end
#  end
#
#  describe "when use event machine style method" do
#    #include EM::MiniTest::Spec
#
#    it "must accept these methods and forward to event machine" do
#      skip
#      OmfCommon.eventloop.after(0.05) { done! }
#      OmfCommon.eventloop.every(0.05) { done! }
#      wait!
#    end
#  end

