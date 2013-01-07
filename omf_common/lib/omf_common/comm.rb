# require 'omf_common/dsl/xmpp'
# require 'omf_common/dsl/xmpp_mp'


module OmfCommon
  # PubSub communication class, can be extended with different implementations
  class Comm
    
    @@drivers = {
      xmpp: {
        require: 'omf_common/dsl/xmpp',
        extend: 'OmfCommon::DSL::Xmpp'
      },
      mock: {
        require: 'omf_common/comm_driver/mock/communicator',
        constructor: 'OmfCommon::CommDriver::Mock::Communicator'
      }
    }
    @@instance = nil
    
    #
    # opts:
    #   :type - pre installed comms driver
    #   :driver - custom driver (opts)
    #     :require - gem to load first (opts)
    #     :constructor - Class implementing driver
    #
    def self.init(opts)
      if @@instance
        raise "Comms layer already iniitalised"
      end
      unless driver = opts[:driver]
        driver = @@drivers[opts[:type]]
      end
      unless driver
        raise "Missing Comm driver declaration. Either define 'type' or 'driver'"
      end

      require driver[:require] if driver[:require]

      if class_name = driver[:extend]
        inst = self.new(nil, driver_class)
      elsif class_name = driver[:constructor]
        driver_class = class_name.split('::').inject(Object) {|c,n| c.const_get(n) }
        inst = driver_class.new(opts)
      else
        raise "Missing driver creation info - :extend or :constructor"
      end
      inst.init(opts)
      @@instance = inst
    end
    
    def self.instance
      @@instance
    end
    
    attr_accessor :published_messages

    def initialize(pubsub_implementation, driver_class_name = nil)
      @published_messages = []
      if driver_class_name
        self.extend(driver_class_name.constantize)
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
