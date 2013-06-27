# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfCommon
class Comm
class XMPP
  class Topic < OmfCommon::Comm::Topic
#    def delete_on_message_cbk_by_id(id)
#      @lock.synchronize do
#        @on_message_cbks[id] && @on_message_cbks.reject! { |k| k == id.to_s }
#      end
#    end

    def address
      #"xmpp://#{id.to_s}@#{OmfCommon.comm.jid.domain}"
      "xmpp://#{id.to_s}@#{@pubsub_domain}"
    end

    def on_subscribed(&block)
      return unless block

      @lock.synchronize do
        @on_subscrided_handlers << block
      end
    end

    private

    def pubsub_domain_addr
      "pubsub.#{@pubsub_domain}"
    end

    def initialize(id, opts = {}, &block)
      id, @pubsub_domain = id.to_s.split("@")
      if id =~ /^xmpp:\/\/(.+)$/
        id = $1
      end
      @pubsub_domain ||= OmfCommon.comm.jid.domain

      super

      @on_subscrided_handlers = []

      topic_block = proc do |stanza|
        if stanza.error?
          block.call(stanza) if block
        else
          block.call(self) if block

          @lock.synchronize do
            @on_subscrided_handlers.each do |handler|
              handler.call
            end
          end
        end
      end

      # Create xmpp pubsub topic, then subscribe to it
      #
      OmfCommon.comm._create(id.to_s, pubsub_domain_addr) do |stanza|
        if stanza.error?
          e_stanza = Blather::StanzaError.import(stanza)
          if e_stanza.name == :conflict
            # Topic exists, just subscribe to it.
            OmfCommon.comm._subscribe(id.to_s, pubsub_domain_addr, &topic_block)
          else
            block.call(stanza) if block
          end
        else
          OmfCommon.comm._subscribe(id.to_s, pubsub_domain_addr, &topic_block)
        end
      end

      event_block = proc do |event|
        OmfCommon::Message.parse(event.items.first.payload) do |parsed_msg|
          on_incoming_message(parsed_msg)
        end
      end

      OmfCommon.comm.topic_event(default_guard, &event_block)
    end

    def _send_message(msg, block)
      super
      OmfCommon.comm.publish(self.id, msg, pubsub_domain_addr)
    end

    def valid_guard?(guard_proc)
      guard_proc && guard_proc.class == Proc
    end

    def default_guard
      proc do |event|
        event.node == self.id.to_s
      end
    end
  end
end
end
end
