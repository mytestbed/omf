require 'amqp'
require 'omf_common/comm_provider/amqp/amqp_topic'
require 'omf_common/comm_provider/monkey_patches'

module OmfCommon
  module CommProvider
    module AMQP
      class Communicator
        
        DEF_PORT = 5672
        
        def initialize(opts = {})
          # ignore arguments
        end

        # Initialize comms layer
        #
        def init(opts = {})
          @server = opts[:server]
          @port = opts[:port] || DEF_PORT
          @address_prefix = "amqp:#{@server}:#{@port}/"
          
          ::AMQP.connect do |connection|
            @channel  = ::AMQP::Channel.new(connection)
            
            if @on_connected_proc
              @on_connected_proc.arity == 1 ? @on_connected_proc.call(self) : @on_connected_proc.call
            end
                      
            # # topic exchange name can be any string
            # exchange = channel.topic("weathr", :auto_delete => true)
#         
            # # Publisher
            # #exchange.publish("San Diego update", :routing_key => "americas.north.us.ca.sandiego")
            # exchange.publish("San Diego update")
        
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
          opts = opts.dup
          opts[:channel] = @channel
          opts[:address] = @address_prefix + topic
          OmfCommon::CommProvider::AMQP::Topic.create(topic, opts)
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
  
        # Subscribe to a pubsub topic
        #
        # @param [String, Array] topic_name Pubsub topic name
        # @param [Hash] opts
        # @option opts [Boolean] :create_if_non_existent create the topic if non-existent, use this option with caution
        #
        def subscribe(topic_name, opts = {}, &block)
          tna = (topic_name.is_a? Array) ? topic_name : [topic_name]
          ta = tna.collect do |tn|
            t = create_topic(tn)
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

      end
    end
  end
end
