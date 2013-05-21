# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

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
