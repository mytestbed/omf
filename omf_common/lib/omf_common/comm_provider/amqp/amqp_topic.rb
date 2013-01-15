

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
        
        # Call 'block' when topic is subscribed to underlying messaging
        # infrastructure. 
        #
        def on_subscribed(&block)
          return unless block
          
          call_now = false
          @lock.synchronize do
            if @subscribed
              call_now = true
            else
              @on_subscrided_handlers << block
            end
          end
          if call_now
            after(0, &block)
          end
        end  
        
        
        private
        
        def initialize(id, opts = {})
          unless channel = opts.delete(:channel)
            raise "Missing :channel option"
          end
          super
          @address = opts[:address]
          @exchange = channel.topic(id, :auto_delete => true)
          @lock = Monitor.new
          @subscribed = false
          @on_subscrided_handlers = []
          
          # Subscribe as well
          #puts "QQ0(#{id})"
          channel.queue("", :exclusive => true) do |queue|
            #puts "QQ1(#{id}): #{queue}"
            queue.bind(@exchange)
            queue.subscribe do |headers, payload|
              #puts "===(#{id}) Incoming message '#{payload}'"
              msg = Message.parse(payload)
              #puts "---(#{id}) Parsed message '#{msg}'"
              on_incoming_message(msg)
            end
            # Call all accumulated on_subscribed handlers
            @lock.synchronize do
              @subscribed = true
              @on_subscrided_handlers.each do |block|
                after(0, &block)
              end
              @on_subscrided_handlers = nil
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
