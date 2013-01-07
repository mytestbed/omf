
require 'monitor'
require 'securerandom'

module OmfCommon
  module CommDriver
    module Mock
      class Topic < OmfCommon::Topic
        @@name2inst = {}
        @@lock = Monitor.new
            
        def self.create(name)
          name = name.to_sym
          @@lock.synchronize do
            unless t = @@name2inst[name]
              t = @@name2inst[name] = self.new(name)
            end
            t
          end
        end
        
        def self.[](name)
          @@name2inst[name]
        end
        
        
        # Request the creation of a new resource. Returns itself    
        #
        def create(res_name, config_opts = {}, &block)
          # new_res = nil
          res_name = res_name.to_sym
          # @@lock.synchronize do
            # # check if already exist
            # if @@name2inst[res_name]
              # raise "Can't create already existing resource '#{res_name}'"
            # end
            # new_res = @@name2inst[res_name] = self.class.new(res_name)
          # end
          config_opts[:name] ||= res_name
          debug "Create resource '#{res_name}'"
          send_message(:create, config_opts, block)
          self
        end
        
        def configure(opts = {}, &block)
          send_message(:configure, opts, block)
          self
        end

        def request(opts = {}, &block)
          # TODO: What are the parameters to the request method really?
          #send_message(:request, opts)
          self
        end

        def inform(type, opts = {}, &block)
          opts[:inform_type] = type
          send_message(:inform, opts, block)
          self
        end

        
        def release(resource = nil, &block)
          # TODO: How do we know parent?
          self
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
        
        private
        
        def initialize(name)
          super name, Comm.instance
          @handlers = {}
          @lock = Monitor.new
          @context2cbk = {}
        end
        
        def send_message(type, msg = {}, block = nil)
          debug "(#{id}) send_message '#{type}': #{msg.inspect}"
          msg[:operation] = type
          msg_id = msg[:msg_id] = SecureRandom.uuid
          msg[:publish_to] = id # Is that really set in the message?
          if (block) 
            # register callback for responses to 'msg_id'
            @context2cbk[msg_id.to_s] = {block: block, last_used: Time.now}
          end

          OmfCommon.eventloop.after(0) do
            debug "(#{id}) deliver message '#{type}': #{msg.inspect}"
            htypes = [type, :message]
            if type == :inform
              if it = msg[:inform_type].to_s.downcase
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
            mo = Message.new(msg)
            hs.each do |block|
              block.call mo
            end
            if cbk = @context2cbk[msg[:context_id].to_s]
              cbk[:last_used] = Time.now
              cbk[:block].call(mo)
            end
          end
        end

      end
    end # module Mock
  end
end
