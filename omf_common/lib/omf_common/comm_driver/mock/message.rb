
module OmfCommon
  module CommDriver
    module Mock
      class Message
        
        INTERNAL_PROPS = [:operation, :uid, :msg_id, :publish_to, :context_id, :inform_type]

        def initialize(content)
          debug "Create message: #{content.inspect}"
          @content = content
        end
        
        [:operation, :msg_id, :publish_to].each do |pname|
          define_method(pname) do ||
            @content[pname]
          end
        end
        
        def read_property(name)
          @content[name.to_sym]
        end
        
        def each_property(&block)
          @content.each do |k, v|
            unless INTERNAL_PROPS.include?(k.to_sym)
              block.call(k, v)
            end
          end
        end
        
        def has_properties?
          f = @content.find do |k, v|
            !INTERNAL_PROPS.include?(k.to_sym)
          end
          !nil
        end
        
        def resource
          #name = @content[:hrn] || @content[:resource_id]
          name = @content[:resource_id]
          Topic.create(name)
        end
        
        def success?
          true
        end
        
        def error?
          false
        end
        
        def to_s
          "Mock::Message: #{@content.inspect}"
        end
        
      end # class
    end
  end
end 