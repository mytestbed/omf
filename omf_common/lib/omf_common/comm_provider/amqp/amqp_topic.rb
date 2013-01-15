

module OmfCommon
  module CommProvider
    module AMQP
      class Topic < OmfCommon::CommProvider::Topic

        # def self.address_for(name)
          # "#{name}@local"
        # end
        
        def to_s
          "AMQP::Topic<#{id}>"
        end
        
        def address
          @address
        end
        
        
        private
        
        def initialize(id, opts = {})
          unless channel = opts.delete(:channel)
            raise "Missing :channel option"
          end
          super
          @address = opts[:address]
          @exchange = channel.topic(id, :auto_delete => true)
          # Subscribe as well
          channel.queue("", :exclusive => true) do |queue|
            queue.bind(@exchange).subscribe do |headers, payload|
              #puts "===(#{id}) Incoming message '#{payload}'"
              msg = Message.parse(payload)
              #puts "---(#{id}) Parsed message '#{msg}'"
              on_incoming_message(msg)
            end
          end
        end
        
        
        def _send_message(msg, block = nil)
          super
          debug "(#{id}) Send message #{msg.inspect}"
          content = msg.marshall
          @exchange.publish(content)
          # OmfCommon.eventloop.after(0) do
            # on_incoming_message(msg)
          # end
        end
        


      end # class
    end # module 
  end # module
end # module
