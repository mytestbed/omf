require 'amqp'
require 'omf_common/comm/amqp/amqp_topic'
#require 'omf_common/comm/monkey_patches'

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
            @on_connected_procs.each do |proc|
              proc.arity == 1 ? proc.call(self) : proc.call
            end
                      
            OmfCommon.eventloop.on_stop do
              connection.close
            end
          end
          super
        end
  
        # Shut down comms layer
        def disconnect(opts = {})
        end
        
        # TODO: Should be thread safe and check if already connected
        def on_connected(&block)
          @on_connected_procs << block
        end
  
        # Create a new pubsub topic with additional configuration
        #
        # @param [String] topic Pubsub topic name
        def create_topic(topic, opts = {})
          raise "Topic can't be nil or empty" if topic.nil? || topic.empty?
          opts = opts.dup
          opts[:channel] = @channel
          topic = topic.to_s
          if topic.start_with? 'amqp:'
            # absolute address
            unless topic.start_with? @address_prefix 
              raise "Cannot subscribe to a topic from different domain (#{topic})"
            end
            opts[:address] = topic
            topic = topic.split(@address_prefix).last
          else
            opts[:address] = @address_prefix + topic
          end
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

        def broadcast_file(file_path, topic_url, opts = {}, &block)
          require 'omf_common/comm/amqp/amqp_file_transfer'
          OmfCommon::Comm::AMQP::FileBroadcaster.new(file_path, @channel, topic_url, opts, &block)
        end
  
        def receive_file(file_path, topic_url, opts = {}, &block)
          require 'omf_common/comm/amqp/amqp_file_transfer'
          FileReceiver.new(file_path, @channel, topic_url, opts, &block)
        end

        private
        def initialize(opts = {})
          @on_connected_procs = []
          super
        end
      end
    end
  end
end
