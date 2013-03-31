require 'omf_common/comm/local/local_topic'

module OmfCommon
  class Comm
    class Local
      class Communicator  < OmfCommon::Comm
               
        # def initialize(opts = {})
          # # ignore arguments
        # end

        # Initialize comms layer
        #
        def init(opts = {})
        end
  
        # Shut down comms layer
        def disconnect(opts = {})
        end
  
        # Create a new pubsub topic with additional configuration
        #
        # @param [String] topic Pubsub topic name
        def create_topic(topic, &block)
          t = OmfCommon::Comm::Local::Topic.create(topic)
          if block
            block.call(t)
          end
          t
        end
  
        # Delete a pubsub topic
        #
        # @param [String] topic Pubsub topic name
        def delete_topic(topic, &block)
          if t = OmfCommon::CommProvider::Local::Topic.find(topic)
            t.release
          else
            warn "Attempt to delete unknown topic '#{topic}"
          end        
        end
  
        def on_connected(&block)
          return unless block
          
          OmfCommon.eventloop.after(0) do
            block.arity == 1 ? block.call(self) : block.call
          end
        end
  
        # Publish to a pubsub topic
        #
        # @param [String] topic Pubsub topic name
        # @param [String] message Any XML fragment to be sent as payload
        # def publish(topic, message, &block)
          # raise StandardError, "Invalid message" unless message.valid?
#   
        # end
  
      end
    end
  end
end
