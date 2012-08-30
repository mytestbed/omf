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

    def on_message(guard_proc, &block)
    end
  end
end
