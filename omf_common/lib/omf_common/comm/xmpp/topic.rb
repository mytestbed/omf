module OmfCommon
class Comm
class XMPP
  class Topic < OmfCommon::Comm::Topic
    %w(creation_ok creation_failed status released error warn).each do |inform_type|
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


    def on_message(message_guard_proc = nil, &message_block)
      event_block = proc do |event|
        message_block.call(OmfCommon::Message.parse(event.items.first.payload))
      end

      guard_block = proc do |event|
        (event.items?) && (!event.delayed?) &&
          event.items.first.payload &&
          (omf_message = OmfCommon::Message.parse(event.items.first.payload)) &&
          event.node == address &&
          (valid_guard?(message_guard_proc) ? message_guard_proc.call(omf_message) : true)
      end
      OmfCommon.comm.topic_event(guard_block, &event_block)
    end

    def inform(type, props = {}, core_props = {}, &block)
      msg = OmfCommon::Message.create(:inform, props, core_props.merge(inform_type: type))
      publish(msg, &block)
      self
    end

    def publish(msg, &block)
      _send_message(msg, &block)
    end

    def address
      id.to_s
    end

    def on_subscribed(&block)
      return unless block

      @lock.synchronize do
        @on_subscrided_handlers << block
      end
    end

    private

    def initialize(id, opts = {})
      super
      @on_subscrided_handlers = []

      OmfCommon.comm.subscribe(id, create_if_non_existent: false) do
        @lock.synchronize do
          @on_subscrided_handlers.each do |handler|
            handler.call
          end
        end
      end
    end

    def _send_message(msg, &block)
      # while sending a message, need to setup handler for replying messages
      OmfCommon.comm.publish(self.id, msg) do |stanza|
        if !stanza.error?
          on_error(msg, &block)
          on_warn(msg, &block)
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

    def valid_guard?(guard_proc)
      guard_proc && guard_proc.class == Proc
    end

  end
end
end
end
