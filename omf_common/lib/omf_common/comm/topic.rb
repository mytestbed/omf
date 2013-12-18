# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'monitor'
require 'securerandom'
require 'openssl'

module OmfCommon
  class Comm
    class Topic

      @@name2inst = {}
      @@lock = Monitor.new

      def self.create(name, opts = {}, &block)
        # Force string conversion as 'name' can be an ExperimentProperty
        name = name.to_s.to_sym
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
        core_props[:src] ||= OmfCommon.comm.local_address
        msg = OmfCommon::Message.create(:inform, props, core_props.merge(itype: type))
        publish(msg, &block)
        self
      end

      def release(resource, core_props = {}, &block)
        unless resource.is_a? self.class
          raise ArgumentError, "Expected '#{self.class}', but got '#{resource.class}'"
        end
        core_props[:src] ||= OmfCommon.comm.local_address
        msg = OmfCommon::Message.create(:release, {}, core_props.merge(res_id: resource.id))
        publish(msg, &block)
        self
      end

      def create_message_and_publish(type, props = {}, core_props = {}, block = nil)
        debug "(#{id}) create_message_and_publish '#{type}': #{props.inspect}"
        core_props[:src] ||= OmfCommon.comm.local_address
        msg = OmfCommon::Message.create(type, props, core_props)
        publish(msg, &block)
      end

      def publish(msg, &block)
        raise "Expected message but got '#{msg.class}" unless msg.is_a?(OmfCommon::Message)
        _send_message(msg, block)
      end

      # TODO we should fix this long list related to INFORM messages
      # according to FRCP, inform types are (underscore form):
      # :creation_ok, :creation_failed, :status, :error, :warn, :released
      #
      # and we shall add :message for ALL types of messages.
      [:created,
        :create_succeeded, :create_failed,
        :inform_status, :inform_failed,
        :released, :failed,
        :creation_ok, :creation_failed, :status, :error, :warn
      ].each do |itype|
        mname = "on_#{itype}"
        define_method(mname) do |*args, &message_block|
          warn_deprecation(mname, :on_message, :on_inform)

          add_message_handler(itype, args.first, &message_block)
        end
      end

      def on_message(key = nil, &message_block)
        add_message_handler(:message, key, &message_block)
      end

      def on_inform(key = nil, &message_block)
        add_message_handler(:inform, key, &message_block)
      end

      # Remove all registered callbacks for 'key'. Will also unsubscribe from the underlying
      # comms layer if no callbacks remain.
      #
      def unsubscribe(key)
        @lock.synchronize do
          @handlers.each do |name, cbks|
            if cbks.delete(key)
              # remove altogether if no callback left
              if cbks.empty?
                @handlers.delete(name)
              end
            end
          end
          if @handlers.empty?
            warn "Should unsubscribe '#{id}'"
          end

          @@name2inst.delete_if { |k, v| k == id.to_sym || k == address.to_sym}
        end
      end

      def on_subscribed(&block)
        raise NotImplementedError
      end

      # For detecting message publishing error, means if callback indeed yield a Topic object, there is no publishing error, thus always false
      def error?
        false
      end

      def address
        raise NotImplementedError
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

      # _send_message will also register callbacks for reply messages by default
      #
      def _send_message(msg, block = nil)
        if (block)
          # register callback for responses to 'mid'
          debug "(#{id}) register callback for responses to 'mid: #{msg.mid}'"
          @lock.synchronize do
            @context2cbk[msg.mid.to_s] = { block: block, created_at: Time.now }
          end
        end
      end

      # Process a message received from this topic.
      #
      # @param [OmfCommon::Message] msg Message received
      #
      def on_incoming_message(msg)
        type = msg.operation
        debug "(#{id}) Deliver message '#{type}': #{msg.inspect}"
        htypes = [type, :message]
        if type == :inform
          # TODO keep converting itype is painful, need to solve this.
          if (it = msg.itype(:ruby)) # format itype as lower case string
            case it
            when "creation_ok"
              htypes << :create_succeeded
            when 'status'
              htypes << :inform_status
            end

            htypes << it.to_sym
          end
        end

        debug "(#{id}) Message type '#{htypes.inspect}' (#{msg.class}:#{msg.cid})"
        hs = htypes.map { |ht| (@handlers[ht] || {}).values }.compact.flatten
        debug "(#{id}) Distributing message to '#{hs.inspect}'"
        hs.each do |block|
          block.call msg
        end
        if cbk = @context2cbk[msg.cid.to_s]
          debug "(#{id}) Distributing message to '#{cbk.inspect}'"
          cbk[:last_used] = Time.now
          cbk[:block].call(msg)
        end
      end

      def add_message_handler(handler_name, key, &message_block)
        raise ArgumentError, 'Missing message callback' if message_block.nil?
        debug "(#{id}) register handler for '#{handler_name}'"
        @lock.synchronize do
          key ||= OpenSSL::Digest::SHA1.new(message_block.source_location.to_s).to_s
          (@handlers[handler_name] ||= {})[key] = message_block
        end
        self
      end

    end
  end
end
