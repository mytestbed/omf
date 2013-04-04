module OmfCommon

  class MPMessage < OML4R::MPBase
    name :message
    param :time, :type => :double
    param :operation, :type => :string
    param :mid, :type => :string
    param :cid, :type => :string
    param :content, :type => :string
  end

  class Message

    OMF_NAMESPACE = "http://schema.mytestbed.net/omf/#{OmfCommon::PROTOCOL_VERSION}/protocol"
    OMF_CORE_READ = [:operation, :ts, :src, :mid, :replyto, :cid, :itype, :rtype, :guard, :res_id]
    OMF_CORE_WRITE = [:replyto, :itype, :guard]

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
    @@authenticate_messages = true

    def self.create(type, properties, body = {})
      @@message_class.create(type, properties || {}, body)
    end

    def self.create_inform_message(itype = nil, properties = {}, body = {})
      body[:itype] = itype if itype
      create(:inform, properties, body)
    end

    # Return true if all messages will be authenticated, return false otherwise
    #
    def self.authenticate?
      @@authenticate_messages
    end

    # Parse message from 'str' and pass it to 'block'.
    # If authnetication is on, the message will only be handed
    # to 'block' if the source of the message can be authenticated.
    #
    def self.parse(str, content_type = nil, &block)
      raise ArgumentError, 'Need message handling block' unless block
      @@message_class.parse(str, content_type, &block)
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
      @@authenticate_messages = opts[:authenticate] if opts[:authenticate]
    end

    OMF_CORE_READ.each do |pname|
      define_method(pname.to_s) do |*args|
        _get_core(pname)
      end
    end

    alias_method :type, :operation

    OMF_CORE_WRITE.each do |pname|
      define_method("#{pname}=") do |val|
        _set_core(pname.to_sym, val)
      end
    end

    # To access properties
    #
    # @param [String] name of the property
    # @param [Hash] ns namespace of property
    def [](name, ns = nil)
      _get_property(name.to_sym, ns)
    end

    # To set properties
    #
    # @param [String] name of the property
    # @param [Hash] ns namespace of property
    def []=(name, ns = nil, value)
      # TODO why itype cannot be set?
      #raise if name.to_sym == :itype
      if ns
        @props_ns ||= {}
        @props_ns.merge(ns)
      end
      _set_property(name.to_sym, value, ns)
    end

    def each_property(&block)
      raise NotImplementedError
    end

    # Loop over all the unbound (sent without a value) properties
    # of a request message.
    #
    def each_unbound_request_property(&block)
      raise NotImplementedError
    end

    # Loop over all the bound (sent with a value) properties
    # of a request message.
    #
    def each_bound_request_property(&block)
      raise NotImplementedError
    end

    def properties
      raise NotImplementedError
    end

    def has_properties?
      not properties.empty?
    end

    def guard?
      raise NotImplementedError
    end

    def resource
      name = _get_property(:res_id)
      OmfCommon.comm.create_topic(name)
    end

    def success?
      ! error?
    end

    def error?
      (itype || '') =~ /(error|ERROR|FAILED)/
    end

    def create_inform_reply_message(itype = nil, properties = {}, body = {})
      body[:cid] = self.mid
      self.class.create_inform_message(itype, properties, body)
    end

    def to_s
      raise NotImplementedError
    end

    def marshall(include_cert = false)
      raise NotImplementedError
    end

    def valid?
      raise NotImplementedError
    end

    # Construct default namespace of the props from resource type
    def default_props_ns
      resource_type = _get_core(:rtype)
      resource_type ? { resource_type.to_s => "#{OMF_NAMESPACE}/#{resource_type}" } : {}
    end

    # Get all property namespace defs
    def props_ns
      @props_ns ||= {}
      default_props_ns.merge(@props_ns)
    end

    private

    def  _get_property(name, ns = nil)
      raise NotImplementedError
    end

    def  _set_property(name, value, ns = nil)
      raise NotImplementedError
    end
  end

end
