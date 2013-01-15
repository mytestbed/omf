# require 'omf_common/dsl/xmpp'
# require 'omf_common/dsl/xmpp_mp'
require 'omf_common/comm_provider/topic'


module OmfCommon
  # PubSub communication class, can be extended with different implementations
  class Comm
    
    @@providers = {
      xmpp: {
        require: 'omf_common/dsl/xmpp',
        extend: 'OmfCommon::DSL::Xmpp',
        message_provider: {
          type: :xml
        }
      },
      amqp: {
        require: 'omf_common/comm_provider/amqp/amqp_communicator',
        constructor: 'OmfCommon::CommProvider::AMQP::Communicator',
        message_provider: {
          type: :json
        }
      },
      local: {
        require: 'omf_common/comm_provider/local/communicator',
        constructor: 'OmfCommon::CommProvider::Local::Communicator',
        message_provider: {
          type: :json
        }
      }
    }
    @@instance = nil
    
    #
    # opts:
    #   :type - pre installed comms provider
    #   :provider - custom provider (opts)
    #     :require - gem to load first (opts)
    #     :constructor - Class implementing provider
    #
    def self.init(opts)
      puts "@@@ #{opts.inspect}"
      if @@instance
        raise "Comms layer already iniitalised"
      end
      unless provider = opts[:provider]
        provider = @@providers[opts[:type]]
      end
      unless provider
        raise "Missing Comm provider declaration. Either define 'type' or 'provider'"
      end

      require provider[:require] if provider[:require]

      if class_name = provider[:extend]
        inst = self.new(nil, provider_class)
      elsif class_name = provider[:constructor]
        provider_class = class_name.split('::').inject(Object) {|c,n| c.const_get(n) }
        inst = provider_class.new(opts)
      else
        raise "Missing provider creation info - :extend or :constructor"
      end
      puts "IIIII #{inst}"
      @@instance = inst
      Message.init(provider[:message_provider])
      inst.init(opts)
    end
    
    def self.instance
      @@instance
    end
    
    attr_accessor :published_messages

    def initialize(pubsub_implementation, provider_class_name = nil)
      @published_messages = []
      if provider_class_name
        self.extend(provider_class_name.constantize)
      else
        self.extend("OmfCommon::DSL::#{pubsub_implementation.to_s.camelize}".constantize)
      end
    end

    # Generate OMF related message
    %w(create configure request inform release).each do |m_name|
      define_method("#{m_name}_message") do |*args, &block|
        message =
          if block
            Message.send(m_name, *args, &block)
          elsif args[0].kind_of? Array
            Message.send(m_name) do |v|
              args[0].each do |opt|
                if opt.kind_of? Hash
                  opt.each_pair do |key, value|
                    v.property(key, value)
                  end
                else
                  v.property(opt)
                end
              end
            end
          else
            Message.send(m_name)
          end

        OmfCommon::TopicMessage.new(message, self)
      end
    end

    %w(created status released failed).each do |inform_type|
      define_method("on_#{inform_type}_message") do |*args, &message_block|
        msg_id = args[0].msg_id if args[0]
        event_block = proc do |event|
          message_block.call(Message.parse(event.items.first.payload))
        end
        guard_block = proc do |event|
          (event.items?) && (!event.delayed?) &&
            event.items.first.payload &&
            (omf_message = Message.parse(event.items.first.payload)) &&
            omf_message.operation == :inform &&
            omf_message.read_content(:inform_type) == inform_type.upcase &&
            (msg_id ? (omf_message.context_id == msg_id) : true)
        end
        topic_event(guard_block, &callback_logging(__method__, &event_block))
      end
    end

    # Return a topic object represents pubsub topic
    #
    def get_topic(topic_id)
      OmfCommon::Topic.new(topic_id, self)
    end
  end
end
