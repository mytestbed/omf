
require 'json'

module OmfCommon
  class Message
    class Json
      class Message < OmfCommon::Message
        

        def self.create(type, properties, body = {})
          if type == :request 
            unless properties.kind_of?(Array)
              raise "Expected array, but got #{properties.class} for request message"
            end
            properties = {select: properties}
          elsif not properties.kind_of?(Hash)
            raise "Expected hash, but got #{properties.class}"
          end 
          content = body.merge({
            operation: type,
            msg_id: SecureRandom.uuid,
            properties: properties
          })
          self.new(content)
        end
        
        def self.create_inform_message(inform_type = nil, properties = {}, body = {})
          body[:inform_type] = inform_type if inform_type
          create(:inform, properties, body)
        end
        
        # Create and return a message by parsing 'str'
        #
        def self.parse(str)
          content = JSON.parse(str, :symbolize_names => true)
          #puts content
          new(content)
        end
                
        def each_property(&block)
          @properties.each do |k, v|
            #unless INTERNAL_PROPS.include?(k.to_sym)
              block.call(k, v)
            #end
          end
        end
        
        def has_properties?
          not @properties.empty?
        end
        
        def valid?
          true # don't do schema verification , yet
        end
        
        # Loop over all the unbound (sent without a value) properties 
        # of a request message.
        #
        def each_unbound_request_property(&block)
          unless type == :request
            raise "Can only be used for request messages"
          end
          self[:select].each do |el|
            #puts "UUU: #{el}::#{el.class}"
            if el.is_a? Symbol
              block.call(el)
            end
          end
        end    
    
        # Loop over all the bound (sent with a value) properties 
        # of a request message.
        #
        def each_bound_request_property(&block)
          unless type == :request
            raise "Can only be used for request messages"
          end
          self[:select].each do |el|
            #puts "BBB #{el}::#{el.class}"
            if el.is_a? Hash
              el.each do |key, value|
                block.call(key, value)
              end
            end
          end
        end    
        
                
        def to_s
          "JsonMessage: #{@content.inspect}"
        end
        
        def marshall
          @content.to_json
        end
        
        private 
        def initialize(content)
          debug "Create message: #{content.inspect}"
          @content = content
          unless op = content[:operation]
            raise "Missing message type (:operation)"
          end
          content[:operation] = op.to_sym # needs to be symbol
          @properties = content[:properties] || []
          #@properties = Hashie::Mash.new(content[:properties])
        end
        
        def _set_core(key, value)
          @content[key] = value
        end

        def _get_core(key)
          @content[key]
        end
        
        def _set_property(key, value)
          @properties[key] = value
        end

        def _get_property(key)
          #puts key
          @properties[key]
        end
        
      end # class
    end
  end
end 