# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'test_helper'
#require 'fixture/pubsub'

require 'omf_common/comm/xmpp/communicator'
require 'omf_common/comm/xmpp/topic'

describe OmfCommon::Comm::XMPP::Topic do
  include EventedSpec::SpecHelper

  # XMPP requires more time
  default_timeout 3.1

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

  it "must allow you to subscribe/unsubscribe to a new pubsub topic" do
    @xmpp_comm.on_connected do |c|
      t_name = SecureRandom.uuid.to_sym
      c.subscribe(t_name) do |topic|
        assert_kind_of OmfCommon::Comm::XMPP::Topic, topic
        assert_match /xmpp:\/\/#{t_name}@/, topic.address

        topic.unsubscribe(t_name)
        done
      end
    end
  end

  it "must allow you to send and monitor messages" do
    @xmpp_comm.on_connected do |c|
      t_name = SecureRandom.uuid.to_sym
      c.subscribe(t_name) do |topic|
        topic.inform('STATUS', attr_1: 'xxx')

        topic.on_message do |msg|
          assert_equal 'xxx', msg[:attr_1]
          done
        end
      end
    end
  end
end
#  before do
#    @client = Blather::Client.new
#    @stream = MiniTest::Mock.new
#    @stream.expect(:send, true, [Blather::Stanza])
#    @client.post_init @stream, Blather::JID.new('n@d/r')
#    @xmpp = OmfCommon::Comm::XMPP::Communicator.new
#
#    OmfCommon.stub :comm, @xmpp do
#      Blather::Client.stub :new, @client do
#        @stream.expect(:send, true, [Blather::Stanza::PubSub::Create])
#        @topic = OmfCommon::Comm::XMPP::Topic.create(:test_topic)
#      end
#    end
#  end
#
#  describe "when calling operation method" do
#    include EM::MiniTest::Spec
#
#    it "must send create message" do
#      skip
#      OmfCommon.stub :comm, @xmpp do
#        Blather::Client.stub :new, @client do
#          published = Blather::XMPPNode.parse(published_xml)
#
#          write_callback = proc do |event|
#            event.must_be_kind_of Blather::Stanza::PubSub::Publish
#            published.id = event.id
#            @client.receive_data published
#          end
#
#          @client.stub :write, write_callback do
#            @xmpp.stub :local_address, 'test_addr' do
#              @topic.create(:bob, { hrn: 'bob' })
#            end
#          end
#        end
#      end
#    end
#
#    it "must trigger operation callbacks" do
#      skip
#      OmfCommon.stub :comm, @xmpp do
#        Blather::Client.stub :new, @client do
#          @client.stub :write, proc {} do
#            @xmpp.stub :local_address, 'test_addr' do
#              omf_create = OmfCommon::Message.create(:create, { type: 'engine' })
#              omf_create.stub :mid, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
#                warn omf_create.mid
#                OmfCommon::Message.stub :create, omf_create do
#                  @topic.create(:bob, { hrn: 'bob' }) do |reply_msg|
#                    error 'bob'
#                    #reply_msg.cid.must_equal "bf840fe9-c176-4fae-b7de-6fc27f183f76"
#                    done!
#                  end
#
#                  @client.receive_data Blather::XMPPNode.parse(omf_created_xml)
#                end
#              end
#            end
#          end
#        end
#      end
#
#      wait!
#    end
#  end
#
#  describe "when informed message received" do
#    include EM::MiniTest::Spec
#
#    it "must react to omf created message" do
#      skip
#      OmfCommon.stub :comm, @xmpp do
#        Blather::Client.stub :new, @client do
#          omf_create = OmfCommon::Message.create(:create, { type: 'engine' })
#          omf_create.stub :mid, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
#            omf_created = Blather::XMPPNode.parse(omf_created_xml)
#            @client.receive_data omf_created
#            @topic.on_creation_ok(omf_create) do |n|
#              OmfCommon::Message.parse(omf_created.items.first.payload) do |parsed_msg|
#                n.stub :ts, parsed_msg.ts do
#                  n.must_equal parsed_msg
#                end
#                done!
#              end
#            end
#          end
#        end
#      end
#      wait!
#    end
#
#    it "must react to omf status message" do
#      skip
#      OmfCommon.stub :comm, @xmpp do
#        Blather::Client.stub :new, @client do
#          omf_request = OmfCommon::Message.create(:request, [:bob])
#          omf_request.stub :mid, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
#            omf_status = Blather::XMPPNode.parse(omf_status_xml)
#            @client.receive_data omf_status
#            @topic.on_status(omf_request) do |n|
#              OmfCommon::Message.parse(omf_status.items.first.payload) do |parsed_msg|
#                n.stub :ts, parsed_msg.ts do
#                  n.must_equal parsed_msg
#                end
#                done!
#              end
#            end
#          end
#        end
#      end
#      wait!
#    end
#
#    it "must react to omf release message" do
#      skip
#      OmfCommon.stub :comm, @xmpp do
#        Blather::Client.stub :new, @client do
#          omf_release = OmfCommon::Message.create(:release, nil, { res_id: '100' })
#          omf_release.stub :mid, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
#            omf_released = Blather::XMPPNode.parse(omf_released_xml)
#            @client.receive_data omf_released
#            @topic.on_released(omf_release) do |n|
#              OmfCommon::Message.parse(omf_released.items.first.payload) do |parsed_msg|
#                n.stub :ts, parsed_msg.ts do
#                  n.must_equal parsed_msg
#                end
#                done!
#              end
#            end
#          end
#        end
#      end
#      wait!
#    end
#
#    it "must react to omf failed message" do
#      skip
#      OmfCommon.stub :comm, @xmpp do
#        Blather::Client.stub :new, @client do
#          omf_create = OmfCommon::Message.create(:create, { type: 'engine' })
#          omf_create.stub :mid, "bf840fe9-c176-4fae-b7de-6fc27f183f76" do
#            omf_failed = Blather::XMPPNode.parse(omf_failed_xml)
#            @client.receive_data omf_failed
#            @topic.on_creation_failed(omf_create) do |n|
#              OmfCommon::Message.parse(omf_failed.items.first.payload) do |parsed_msg|
#                n.stub :ts, parsed_msg.ts do
#                  n.must_equal parsed_msg
#                end
#                done!
#              end
#            end
#          end
#        end
#      end
#      wait!
#    end
#  end
#end
