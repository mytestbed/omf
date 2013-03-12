

module OmfCommon
  class Comm
    class Local
      class Topic < OmfCommon::Comm::Topic
        @@marshall_messages = true
        
        # If set to 'true' marshall and immediately unmarshall before handing it on
        # messages
        def self.marshall_messages=(flag)
          @@marshall_messages = (flag == true)
        end
        
        # def self.address_for(name)
          # "#{name}@local"
        # end
        
        def to_s
          "Mock::Topic<#{id}>"
        end
        
        def address
          "local:/#{id}"
        end
        
        def on_subscribed(&block)
          return unless block
          
          OmfCommon.eventloop.after(0) do
            block.arity == 1 ? block.call(self) : block.call
          end
        end  
              
        private
        
        def _send_message(msg, block = nil)
          super
          debug "(#{id}) Send message #{msg.inspect}"
          if @@marshall_messages
            content_type, payload = msg.marshall
            msg = Message.parse(payload, content_type)
          end
          OmfCommon.eventloop.after(0) do
            on_incoming_message(msg)
          end
        end
        

      end # class
    end # module 
  end # module
end # module
