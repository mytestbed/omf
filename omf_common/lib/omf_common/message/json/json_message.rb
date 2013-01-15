
require 'json'

module OmfCommon
  module Message
    module Json
      class JsonMessage < OmfCommon::Message::AbstractMessage
        

        def self.create(type, properties, body = {})
          raise "Expected hash, but got #{properties.class}" unless properties.kind_of?(Hash)
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
        

        
        # [:operation, :msg_id, :publish_to, :inform_to, :resource_id, :context_id, :inform_type].each do |pname|
          # define_method(pname.to_s) do |*args|
            # @content[pname]
          # end
        # end
#         
        # def type
          # @content[:operation]
        # end
#         
        # #[:publish_to, :inform_to, :resource_id].each do |pname|
        # [:publish_to, :resource_id, :inform_type].each do |pname|
          # define_method("#{pname}=") do |val|
            # @content[pname.to_sym] = val
          # end
        # end        
#         
        # def property
          # Hashie::Mash.new @properties
        # end
# 
        # def properties
          # @properties
        # end
# 
        # def read_property(name)
          # @properties[name.to_sym]
        # end
#         
        # def [](name)
          # @properties[name.to_sym]
        # end
#         
        # def []=(name, value)
          # raise if name.to_sym == :inform_type
          # @properties[name.to_sym] = value
        # end
        
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
          @properties[key]
        end
        
      end # class
    end
  end
end 