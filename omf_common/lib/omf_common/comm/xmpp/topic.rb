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
      "xmpp://#{id.to_s}@#{OmfCommon.comm.jid.domain}"
    end

    def on_subscribed(&block)
      return unless block

      @lock.synchronize do
        @on_subscrided_handlers << block
      end
    end

    private

    def initialize(id, opts = {}, &block)
      id = $1 if id =~ /^xmpp:\/\/(.+)@.+$/

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
      OmfCommon.comm._create(id.to_s) do |stanza|
        if stanza.error?
          e_stanza = Blather::StanzaError.import(stanza)
          if e_stanza.name == :conflict
            # Topic exists, just subscribe to it.
            OmfCommon.comm._subscribe(id.to_s, &topic_block)
          else
            block.call(stanza) if block
          end
        else
          OmfCommon.comm._subscribe(id.to_s, &topic_block)
        end
      end

      event_block = proc do |event|
        error 'FFS'

        OmfCommon::Message.parse(event.items.first.payload) do |parsed_msg|
          on_incoming_message(parsed_msg)
        end
      end

      OmfCommon.comm.topic_event(default_guard, &event_block)
    end

    def _send_message(msg, block)
      super
      OmfCommon.comm.publish(self.id, msg)
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
