

module OmfCommon
  class Comm
    class Local
      class Topic < OmfCommon::Comm::Topic

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
          OmfCommon.eventloop.after(0) do
            on_incoming_message(msg)
          end
        end
        

      end # class
    end # module 
  end # module
end # module
