module OmfCommon
  class TopicMessage
    attr_accessor :body, :comm

    def initialize(body, comm)
      self.body ||= body
      self.comm ||= comm
    end
  end
end
