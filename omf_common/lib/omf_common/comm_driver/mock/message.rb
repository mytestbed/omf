
module OmfCommon
  module CommDriver
    module Mock
      class Message
        
        INTERNAL_PROPS = [:operation, :uid, :msg_id, :publish_to, :context_id, :inform_type]

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

        
        [:operation, :msg_id, :publish_to, :inform_to, :resource_id, :context_id, :inform_type].each do |pname|
          define_method(pname.to_s) do |*args|
            @content[pname]
          end
        end
        
        def type
          @content[:operation]
        end
        
        #[:publish_to, :inform_to, :resource_id].each do |pname|
        [:publish_to, :resource_id, :inform_type].each do |pname|
          define_method("#{pname}=") do |val|
            @content[pname.to_sym] = val
          end
        end        
        
        def property
          Hashie::Mash.new @properties
        end

        def properties
          @properties
        end

        def read_property(name)
          @properties[name.to_sym]
        end
        
        def [](name)
          @properties[name.to_sym]
        end
        
        def []=(name, value)
          raise if name.to_sym == :inform_type
          @properties[name.to_sym] = value
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
          # f = @content.find do |k, v|
            # !INTERNAL_PROPS.include?(k.to_sym)
          # end
          # !nil
        end
        
        def resource
          #name = @content[:hrn] || @content[:resource_id]
          name = @properties[:resource_id]
          Topic.create(name)
        end
        
        def success?
          true
        end
        
        def error?
          false
        end
        
        def create_inform_message(inform_type = nil, properties = {}, body = {})
          body[:context_id] = self.msg_id
          self.class.create_inform_message(inform_type, properties, body)
        end
        
        def to_s
          "Mock::Message: #{@content.inspect}"
        end
        
        private 
        def initialize(content)
          debug "Create message: #{content.inspect}"
          @content = content
          @properties = content[:properties] || []
          #@properties = Hashie::Mash.new(content[:properties])
        end
        
        
      end # class
    end
  end
end 