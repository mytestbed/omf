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
          @distributed_files = {}
					super
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
  
        def broadcast_file(file_path, topic_url, opts = {}, &block)
          @distributed_files[topic_url] = file_path
          "local:#{topic_url}"
        end
  
        def receive_file(file_path, topic_url, opts = {}, &block)
          OmfCommon.eventloop.after(0) do
            unless original = @distributed_files[topic_url]
              raise "File '#{topic_url}' hasn't started broadcasting"
            end
            `cp #{original} #{file_path}`
            unless $?.success?
              error "Couldn't copy '#{original}' to '#{file_path}'"
            end
            if block
              block.call({action: :done, size: -1, received: -1})
            end
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
