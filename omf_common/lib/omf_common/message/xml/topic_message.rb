# module OmfCommon
  # class TopicMessage
    # attr_accessor :body, :comm
# 
    # def initialize(body, comm)
      # self.body ||= body
      # self.comm ||= comm
    # end
# 
    # def publish(topic_id, &block)
      # comm.publish(topic_id, body.dup, &block)
    # end
# 
    # %w(created status failed released).each do |itype|
      # define_method("on_inform_#{itype}") do |*args, &message_block|
        # comm.send("on_#{itype}_message", body, &message_block)
      # end
    # end
  # end
# end
