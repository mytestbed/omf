
require 'monitor'
require 'securerandom'

module OmfCommon
  module CommProvider
    module Local
      class Topic < OmfCommon::CommProvider::Topic

        # def self.address_for(name)
          # "#{name}@local"
        # end
        
        def to_s
          "Mock::Topic<#{id}>"
        end
        
        def address
          "local:/#{id}"
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
