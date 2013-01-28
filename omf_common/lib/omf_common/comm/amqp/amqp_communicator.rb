require 'amqp'
require 'omf_common/comm/amqp/amqp_topic'
require 'omf_common/comm/monkey_patches'

module OmfCommon
  class Comm
    class AMQP
      class Communicator < OmfCommon::Comm
        
        # def initialize(opts = {})
          # # ignore arguments
        # end

        # Initialize comms layer
        #
        def init(opts = {})
          unless (@url = opts[:url])
            raise "Missing 'url' option for AQMP layer"
          end
          @address_prefix = @url + '/'
          ::AMQP.connect(@url) do |connection|
            @channel  = ::AMQP::Channel.new(connection)
            
            if @on_connected_proc
              @on_connected_proc.arity == 1 ? @on_connected_proc.call(self) : @on_connected_proc.call
            end
                      
            OmfCommon.eventloop.on_stop do
              connection.close
            end
          end
        end
  
        # Shut down comms layer
        def disconnect(opts = {})
        end
        
        def on_connected(&block)
          @on_connected_proc = block
        end
  
        # Create a new pubsub topic with additional configuration
        #
        # @param [String] topic Pubsub topic name
        def create_topic(topic, opts = {})
          raise "Topic can't be nil or empty" if topic.nil? || topic.empty?
          opts = opts.dup
          opts[:channel] = @channel
          opts[:address] = @address_prefix + topic
          OmfCommon::Comm::AMQP::Topic.create(topic, opts)
        end
  
        # Delete a pubsub topic
        #
        # @param [String] topic Pubsub topic name
        def delete_topic(topic, &block)
          if t = OmfCommon::CommProvider::AMQP::Topic.find(topic)
            t.release
          else
            warn "Attempt to delete unknown topic '#{topic}"
          end        
        end
  
      end
    end
  end
end
