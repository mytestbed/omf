module OmfCommon

  class MPMessage < OML4R::MPBase
    name :message
    param :time, :type => :double
    param :operation, :type => :string
    param :msg_id, :type => :string
    param :context_id, :type => :string
    param :content, :type => :string
  end

  class Message

    @@providers = {
      xml: {
        require: 'omf_common/message/xml/message',
        constructor: 'OmfCommon::Message::XML::Message'
      },
      json: {
        require: 'omf_common/message/json/json_message',
        constructor: 'OmfCommon::Message::Json::Message'
      }
    }
    @@message_class = nil

    def self.create(type, properties, body = {})
      @@message_class.create(type, properties, body)
    end

    def self.create_inform_message(inform_type = nil, properties = {}, body = {})
      body[:inform_type] = inform_type if inform_type
      create(:inform, properties, body)
    end

    # Create and return a message by parsing 'str'
    #
    def self.parse(str)
      @@message_class.parse(str)
    end

    def self.init(opts = {})
      if @@message_class
        raise "Message provider already iniitalised"
      end
      unless provider = opts[:provider]
        provider = @@providers[opts[:type]]
      end
      unless provider
        raise "Missing Message provider declaration. Either define 'type' or 'provider'"
      end

      require provider[:require] if provider[:require]

      if class_name = provider[:constructor]
        @@message_class = class_name.split('::').inject(Object) {|c,n| c.const_get(n) }
      else
        raise "Missing provider class info - :constructor"
      end
    end


    INTERNAL_PROPS = [:operation, :uid, :msg_id, :publish_to, :context_id, :inform_type]

    [:operation, :msg_id, :publish_to, :inform_to, :resource_id, :context_id, :inform_type].each do |pname|
      define_method(pname.to_s) do |*args|
        _get_core(pname)
      end
    end

    def type
      _get_core(:operation)
    end

    [:publish_to, :resource_id, :inform_type].each do |pname|
      define_method("#{pname}=") do |val|
        _set_core(pname.to_sym, val)
      end
    end

    def [](name)
      _get_property(name.to_sym)
    end

    def []=(name, value)
      raise if name.to_sym == :inform_type
      _set_property(name.to_sym, value)
    end

    def each_property(&block)
      raise NotImplementedError
    end
    
    # Loop over all the unbound (sent without a value) properties 
    # of a request message.
    #
    def each_unbound_request_property(&block)
      raise "Not implemented"
    end    

    # Loop over all the bound (sent with a value) properties 
    # of a request message.
    #
    def each_bound_request_property(&block)
      raise "Not implemented"
    end    
    
    def has_properties?
      raise NotImplementedError
    end

    def resource
      name = _get_property(:resource_id)
      OmfCommon.comm.create_topic(name)
    end

    def success?
      ! error?
    end

    def error?
      (inform_type || '').start_with? 'error'
    end

    def create_inform_reply_message(inform_type = nil, properties = {}, body = {})
      body[:context_id] = self.msg_id
      self.class.create_inform_message(inform_type, properties, body)
    end

    def to_s
      raise NotImplementedError
    end

    def marshall
      raise NotImplementedError
    end
  end

end
