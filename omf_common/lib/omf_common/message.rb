
module OmfCommon

  class MPMessage < OML4R::MPBase
    name :message
    param :time, :type => :double
    param :operation, :type => :string
    param :msg_id, :type => :string
    param :context_id, :type => :string
    param :content, :type => :string
  end

  module Message
    
    @@providers = {
      xml: {
        require: 'omf_common/message_provider/xml/message',
        extend: 'OmfCommon::MessageProvider::XML::Message'
      },
      json: {
        require: 'omf_common/message_provider/json/json_message',
        constructor: 'OmfCommon::MessageProvider::Json::Message'
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
  end

end
