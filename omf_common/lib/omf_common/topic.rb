module OmfCommon
  class Topic
    attr_accessor :id, :comm

    def initialize(id, comm)
      self.id ||= id
      self.comm ||= comm
    end

    def subscribe(&block)
      comm.subscribe(id, &block)
    end

    def on_message(message_guard_proc = nil, &message_block)
      event_block = proc do |event|
        message_block.call(Message.parse(event.items.first.payload))
      end
      guard_block = proc do |event|
        (event.items?) && (!event.delayed?) &&
          event.items.first.payload &&
          (omf_message = Message.parse(event.items.first.payload)) &&
          event.node == self.id &&
          (valid_guard?(message_guard_proc) ? message_guard_proc.call(omf_message) : true)
      end
      comm.pubsub_event(guard_block, &event_block)
    end

    private

    def valid_guard?(guard_proc)
      guard_proc && guard_proc.class == Proc
    end
  end
end
