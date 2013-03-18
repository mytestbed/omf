require 'monitor'
require 'securerandom'

module OmfCommon
  class Comm
    class Topic

      @@name2inst = {}
      @@lock = Monitor.new

      def self.create(name, opts = {}, &block)
        name = name.to_sym
        @@lock.synchronize do
          unless @@name2inst[name]
            debug "New topic: #{name}"
            #opts[:address] ||= address_for(name)
            @@name2inst[name] = self.new(name, opts, &block)
          else
            debug "Existing topic: #{name}"
            block.call(@@name2inst[name]) if block
          end
          @@name2inst[name]
        end
      end

      def self.[](name)
        @@name2inst[name]
      end

      attr_reader :id

      # Request the creation of a new resource. Returns itself
      #
      def create(res_type, config_props = {}, core_props = {}, &block)
        # new_res = nil
        #res_name = res_name.to_sym
        #config_props[:name] ||= res_name
        config_props[:type] ||= res_type
        debug "Create resource of type '#{res_type}'"
        create_message_and_publish(:create, config_props, core_props, block)
        self
      end

      def configure(props = {}, core_props = {}, &block)
        create_message_and_publish(:configure, props, core_props, block)
        self
      end

      def request(select = [], core_props = {}, &block)
        # TODO: What are the parameters to the request method really?
        create_message_and_publish(:request, select, core_props, block)
        self
      end

      def inform(type, props = {}, core_props = {}, &block)
        msg = OmfCommon::Message.create(:inform, props, core_props.merge(itype: type))
        publish(msg, &block)
        self
      end

      # def inform(type, props = {}, &block)
        # msg = OmfCommon::Message.create(:inform, props)
        # msg.itype = type
        # publish(msg, &block)
        # self
      # end

      def release(resource, core_props = {}, &block)
        unless resource.is_a? self.class
          raise "Expected '#{self.class}', but got '#{resource.class}'"
        end
        core_props[:src] ||= Comm.instance.local_address
        msg = OmfCommon::Message.create(:release, {}, core_props.merge(res_id: resource.id))
        publish(msg, &block)
        self
      end


      def create_message_and_publish(type, props = {}, core_props = {}, block = nil)
        debug "(#{id}) create_message_and_publish '#{type}': #{props.inspect}"
        core_props[:src] ||= Comm.instance.local_address
        msg = OmfCommon::Message.create(type, props, core_props)
        publish(msg, &block)
      end

      def publish(msg, &block)
        # TODO should it be _send_message(msg, &block) ?
        #raise "Expected message but got '#{msg.class}" unless msg.is_a?(OmfCommon::Message)
        _send_message(msg, block)
      end

      [:created,
        :create_succeeded, :create_failed,
        :inform_status, :inform_failed,
        :released, :failed,
        :message
      ].each do |itype|
        mname = "on_#{itype}"
        define_method(mname) do |*args, &message_block|
          debug "(#{id}) register handler for '#{mname}'"
          @lock.synchronize do
            (@handlers[itype] ||= []) << message_block
          end
          self
        end
      end

      # Unsubscribe from the underlying comms layer
      #
      def unsubscribe()

      end

      def on_subscribed(&block)
        raise "Not implemented"
      end

      # For detecting message publishing error, means if callback indeed yield a Topic object, there is no publishing error, thus always false
      def error?
        false
      end

      def address
        raise "Not implemented"
      end

      def after(delay_sec, &block)
        return unless block
        OmfCommon.eventloop.after(delay_sec) do
          block.arity == 1 ? block.call(self) : block.call
        end
      end

      private

      def initialize(id, opts = {})
        @id = id
        #@address = opts[:address]
        @handlers = {}
        @lock = Monitor.new
        @context2cbk = {}
      end


      def _send_message(msg, block = nil)
        if (block)
          # register callback for responses to 'mid'
          @context2cbk[msg.mid.to_s] = {block: block, created_at: Time.now}
        end
      end

      # Process a message received from this topic. 
      #
      # @param [OmfCommon::Message] msg Message received
      # @param [Hash] auth_info Authentication information
      # @option auth_info [Symbol] :signer Id  
      def on_incoming_message(msg)
        type = msg.operation
        debug "(#{id}) Deliver message '#{type}': #{msg.inspect}"
        htypes = [type, :message]
        if type == :inform
          if it = msg.itype.to_s.downcase
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

        debug "(#{id}) Message type '#{htypes.inspect}' (#{msg.class}:#{msg.cid})"
        hs = htypes.map do |ht| @handlers[ht] end.compact.flatten
        debug "(#{id}) Distributing message to '#{hs.inspect}'"
        hs.each do |block|
          block.call msg
        end
        if cbk = @context2cbk[msg.cid.to_s]
          debug "(#{id}) Distributing message to '#{cbk.inspect}'"
          cbk[:last_used] = Time.now
          cbk[:block].call(msg)
        # else
          # if msg.cid
            # puts "====NOOOO for #{msg.cid} - #{@context2cbk.keys.inspect}"
          # end
        end

      end


    end
  end
end
