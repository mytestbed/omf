module OmfCommon
class Comm
class XMPP
  class Topic < OmfCommon::Comm::Topic
    %w(creation_ok creation_failed status released).each do |inform_type|
      define_method("on_#{inform_type}") do |*args, &message_block|
        msg_id = args[0].msg_id if args[0]

        event_block = proc do |event|
          message_block.call(OmfCommon::Message.parse(event.items.first.payload))
        end

        guard_block = proc do |event|
          (event.items?) && (!event.delayed?) &&
            event.items.first.payload &&
            (omf_message = OmfCommon::Message.parse(event.items.first.payload)) &&
            omf_message.operation == :inform &&
            omf_message.read_content(:inform_type) == inform_type.upcase &&
            (msg_id ? (omf_message.context_id == msg_id) : true)
        end

        OmfCommon.comm.topic_event(guard_block, &event_block)
      end
    end

    def publish(msg, &block)
      _send_message(msg, &block)
    end

    private

    def _send_message(msg, &block)
      # while sending a message, need to setup handler for replying messages

      OmfCommon.comm.publish(self.id, msg) do |stanza|
        if !stanza.error?
          case msg.operation
          when :create
            on_creation_ok(msg, &block)
            on_creation_failed(msg, &block)
          when :configure, :request
            on_status(msg, &block)
          when :release
            on_released(msg, &block)
          end
        end
      end
    end

  end
end
end
end
