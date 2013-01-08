
require 'monitor'
require 'securerandom'

module OmfCommon
  module CommDriver
    module Mock
      class Topic < OmfCommon::Topic
        @@name2inst = {}
        @@lock = Monitor.new
            
        def self.create(name, opts = {})
          name = name.to_sym
          @@lock.synchronize do
            unless t = @@name2inst[name]
              opts[:address] ||= address_for(name)
              t = @@name2inst[name] = self.new(name, opts)
            end
            t
          end
        end
        
        def self.[](name)
          @@name2inst[name]
        end
        
        def self.address_for(name)
          "#{name}@local"
        end
        
        attr_reader :address
        
        # Request the creation of a new resource. Returns itself    
        #
        def create(res_name, config_props = {}, &block)
          # new_res = nil
          res_name = res_name.to_sym
          # @@lock.synchronize do
            # # check if already exist
            # if @@name2inst[res_name]
              # raise "Can't create already existing resource '#{res_name}'"
            # end
            # new_res = @@name2inst[res_name] = self.class.new(res_name)
          # end
          config_props[:name] ||= res_name
          debug "Create resource '#{res_name}'"
          create_and_send_message(:create, config_props, block)
          self
        end
        
        def configure(props = {}, &block)
          create_and_send_message(:configure, props, block)
          self
        end

        def request(props = {}, &block)
          # TODO: What are the parameters to the request method really?
          #create_and_send_message(:request, props)
          self
        end

        def inform(type, props = {}, &block)
          msg = Message.create(:inform, props)
          msg.inform_type = type
          send_message(msg, block)
          self
        end

        
        def release(resource, &block)
          unless resource.is_a? self.class
            raise "Expected '#{self.class}', but got '#{resource.class}'"
          end
          msg = Message.create(:release, {}, {resource_id: resource.id})
          send_message(msg, block)
          self
        end
        
        def publish(msg, &block)
          raise "Expected message but got '#{msg.class}" unless msg.is_a?(Message)
          send_message(msg, block)
        end
        
        [:created, 
          :create_succeeded, :create_failed, 
          :inform_status, :inform_failed, 
          :released, :failed, 
          :message
        ].each do |inform_type|
          mname = "on_#{inform_type}"
          define_method(mname) do |*args, &message_block|
            debug "(#{id}) register handler for '#{mname}'"
            @lock.synchronize do
              (@handlers[inform_type] ||= []) << message_block
            end
            self
          end
        end
        
        # Convenience method for delayed execution
        #
        def after(time, &block)
          OmfCommon.eventloop.after(time, &block)
        end
        
        # Unsubscribe from the underlying comms layer 
        #
        def unsubscribe()
          
        end
        
        # # What exactly does this cover?
        # def on_inform_failed(&message_block)
          # info "register handler for 'on_inform_failed'"
          # self
        # end
#         
        # def on_created_failed(&message_block)
          # info "register handler for 'on_created_failed'"
          # self
        # end
#         
        # def on_message(message_guard_proc = nil, &message_block)
          # info "register handler for ANY message"
          # self
        # end
        
        
        def error?
          false
        end
        
        def to_s
          "Mock::Topic<#{id}>"
        end
        
        private
        
        def initialize(name, opts = {})
          super name, Comm.instance
          @address = opts[:address]
          @handlers = {}
          @lock = Monitor.new
          @context2cbk = {}
        end
        
        def create_and_send_message(type, props = {}, block = nil)
          debug "(#{id}) Create_and_send_message '#{type}': #{props.inspect}"
          msg = Message.create(type, props)
          #msg[:operation] = type
          #msg_id = msg[:msg_id] = SecureRandom.uuid
          msg.publish_to = id # Is that really set in the message?
          send_message(msg, block)
        end
        
        def send_message(msg, block = nil)
          if (block) 
            # register callback for responses to 'msg_id'
            @context2cbk[msg.msg_id.to_s] = {block: block, created_at: Time.now}
          end
          debug "(#{id}) Send message #{msg.inspect}"
          OmfCommon.eventloop.after(0) do
            on_incoming_message(msg)
          end
        end
        
        def on_incoming_message(msg)
          type = msg.operation
          debug "(#{id}) Deliver message '#{type}': #{msg.inspect}"
          htypes = [type, :message]
          if type == :inform
            if it = msg.inform_type.to_s.downcase
              #puts "TTT> #{it}"
              case it
              when "creation_ok"
                htypes << :create_succeeded
              when 'status'
                htypes << :inform_status
              else
                htypes << it.to_sym
              end
            end
          end
          
          debug "(#{id}) Message type '#{htypes.inspect}' (#{msg.class}:#{msg[:context_id]})"
          hs = htypes.map do |ht| @handlers[ht] end.compact.flatten
          debug "(#{id}) Distributing message to '#{hs.inspect}'"
          hs.each do |block|
            block.call msg
          end
          if cbk = @context2cbk[msg.context_id.to_s]
            debug "(#{id}) Distributing message to '#{cbk.inspect}'"
            cbk[:last_used] = Time.now
            cbk[:block].call(msg)
          # else
            # if msg.context_id
              # puts "====NOOOO for #{msg.context_id} - #{@context2cbk.keys.inspect}"
            # end
          end
          
        end

      end
    end # module Mock
  end
end
