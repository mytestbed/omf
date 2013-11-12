# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.



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
            content_type, payload = msg.marshall(self)
            Message.parse(payload, content_type) do
              OmfCommon.eventloop.after(0) do
                on_incoming_message(msg)
              end   
            end
          else
            OmfCommon.eventloop.after(0) do
              on_incoming_message(msg)
            end
          end
        end
        

      end # class
    end # module 
  end # module
end # module
