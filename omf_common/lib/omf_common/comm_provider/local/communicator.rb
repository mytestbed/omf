require 'omf_common/comm_provider/local/topic'
require 'omf_common/comm_provider/monkey_patches'

module OmfCommon
  module CommProvider
    module Local
      class Communicator
        
        def initialize(pubsub_implementation, driver_class_name = nil)
          # ignore arguments
        end

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
          warn "Why use 'create_topic'"
          Topic.create(topic)
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
  
        # Subscribe to a pubsub topic
        #
        # @param [String, Array] topic_name Pubsub topic name
        # @param [Hash] opts
        # @option opts [Boolean] :create_if_non_existent create the topic if non-existent, use this option with caution
        #
        def subscribe(topic_name, opts = {}, &block)
          tna = (topic_name.is_a? Array) ? topic_name : [topic_name]
          ta = tna.collect do |tn|
            t = OmfCommon::CommProvider::Local::Topic.create(tn)
            if block
              block.call(t)
            end
            t
          end
          ta[0]
        end
  
        # Un-subscribe all existing subscriptions from all pubsub topics.
        def unsubscribe_all
          info "unsubscribe to ALL"          
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
