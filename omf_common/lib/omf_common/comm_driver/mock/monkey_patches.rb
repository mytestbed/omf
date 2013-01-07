
require 'omf_common/comm_driver/mock/message'

module OmfRc
  module ResourceProxy
    require 'omf_rc/resource_proxy/abstract_resource'
    
    class AbstractResource
      
      # Initialisation
      #
      # @param [Symbol] type resource proxy type
      # @param [Hash] opts options to be initialised
      # @option opts [String] :uid Unique identifier
      # @option opts [String] :hrn Human readable name
      # @option opts [Hash] :property A hash for keeping internal state
      # @option opts [Hash] :instrument A hash for keeping instrumentation-related state
      # 
      def initialize(type, opts = nil, comm = nil)
        @opts = Hashie::Mash.new(opts)
        @type = type
        @uid = @opts.uid || SecureRandom.uuid
        @children ||= []
        @membership ||= []
        if @hrn = @opts.hrn
          @hrn = @hrn.to_s
          @membership << @hrn
        end
        @topic = nil # fill in below
        
        @property = @opts.property || Hashie::Mash.new
        OmfCommon.comm.subscribe(@hrn ? [@uid, @hrn] : @uid) do |t|
          if t.id.to_s == @uid
            @topic = t 
          end
          if t.error?
              warn "Could not create topic '#{uid}', will shutdown, trying to clean up old topics. Please start it again once it has been shutdown."
              OmfCommon.comm.disconnect()
          else
            t.inform(:created, {resource_id: @uid, hrn: @hrn})

            t.on_message do |msg|
              #puts ">>>> #{t.id}: #{msg}"
              process_omf_message(msg, t)
            end
          end
        end
      end
      
      # Parse omf message and execute as instructed by the message
      #
      def process_omf_message(props, topic)
        if props.is_a? OmfCommon::CommDriver::Mock::Message
          message = props
        else
          message = OmfCommon::CommDriver::Mock::Message.new(props.dup)
        end
    #puts "PPP(#{topic.id}|#{uid})-> #{message}"
        objects_by_topic(topic.id.to_s).each do |obj|
    #puts "TTT-> #{message}"
          if OmfCommon::Measure.enabled?
            OmfRc::ResourceProxy::MPReceived.inject(Time.now.to_f, self.uid, topic, message.msg_id) 
          end
          execute_omf_operation(message, obj, topic)
        end
      end
      
      def execute_omf_operation(message, obj, topic)
        response_h = handle_message(message, obj)
        response = Hashie::Mash.new(response_h)
        case response.operation
        when :create
          #puts "CCCC(#{topic.id})==> #{response_h.inspect}"
          #topic.inform('CREATION_OK', response_h)
          inform(:created, response_h, topic)
          new_uid = response.resource_id
          # @comm.create_topic(new_uid) do
            # @comm.subscribe(new_uid) do
              # inform(:created, response)
            # end
          # end
        when :request, :configure
          inform(:status, response_h, topic)
        when :release
          OmfCommon.eventloop.after(RELEASE_WAIT) do
            inform(:released, response_h, topic)
          end
        end
      end
      
      def handle_message(message, obj)
        default_response = {
          operation: message.operation,
          context_id: message.msg_id,
          inform_to: inform_to_address(obj, message.publish_to)
        }
    
        case message.operation
        when :create
          handle_create_message(message, obj, default_response)
        when :request, :configure
          handle_request_or_configure_message(message, obj, default_response)        
        when :release
          resource_id = message.resource_id
          released_obj = obj.release(resource_id)
          released_obj ? default_response.merge(resource_id: released_obj.uid) : nil
        when :inform
          nil # We really don't care about inform messages which created from here
        else
          raise StandardError, <<-ERROR
            Invalid message received (Unknown OMF operation #{message.operation}): #{pubsub_item_payload}.
            Please check protocol schema of version #{OmfCommon::PROTOCOL_VERSION}.
          ERROR
        end
      end
      
      def handle_create_message(message, obj, default_response)
        new_name = message.read_property(:name) || message.read_property(:hrn)
        new_opts = opts.dup.merge(uid: nil, hrn: new_name)
        new_obj = obj.create(message.read_property(:type), new_opts)
        exclude = [:type, :hrn, :name]
        message.each_property do |key, value|
          unless exclude.include?(key)
            method_name = "configure_#{key}"
            new_obj.__send__(method_name, value)
          end
        end
        new_obj.after_initial_configured if new_obj.respond_to? :after_initial_configured
        default_response.merge(resource_id: new_obj.uid)
      end   
      
      def handle_request_or_configure_message(message, obj, default_response)
        result = Hashie::Mash.new.tap do |mash|
          if message.operation == :request && message.has_properties?
            obj.request_available_properties.request.each do |r_p|
              method_name = "request_#{r_p.to_s}"
              mash[r_p] ||= obj.__send__(method_name)
            end
          else
            message.each_property do |key, value|
              method_name =  "#{message.operation.to_s}_#{key}"
              p_value = message.read_property(key)
              mash[key] ||= obj.__send__(method_name, p_value)
            end
          end
        end
        # Always return uid
        result.uid = obj.uid
        default_response.merge(status: result)
      end  
      
      # Publish an inform message
      # @param [Symbol] inform_type the type of inform message
      # @param [Hash | Hashie::Mash | Exception | String] inform_data the type of inform message
      def inform(inform_type, inform_data, topic = nil)
        topic ||= @topic
        inform_data = Hashie::Mash.new(inform_data) if inform_data.class == Hash
        case inform_type
        when :failed
          unless inform_data.kind_of? Exception
            raise ArgumentError, "FAILED message requires an Exception (or MessageProcessError)"
          end
        when :created, :released
          unless inform_data.respond_to?(:resource_id) && !inform_data.resource_id.nil?
            raise ArgumentError, "CREATED or RELEASED message requires inform_data object respond to resource_id"
          end
        when :status
          unless inform_data.respond_to?(:status) && inform_data.status.kind_of?(Hash)
            raise ArgumentError, "STATUS message requires a hash represents properties"
          end
        end

        context_id = inform_data.context_id if inform_data.respond_to? :context_id
        inform_to = inform_data.inform_to if inform_data.respond_to? :inform_to
        inform_to ||= self.uid
    
        params = {}
        params[:context_id] = context_id if context_id
        case inform_type
        when :created
          params[:resource_id] = inform_data.resource_id
          params[:resource_address] = inform_data.resource_id
        when :status
          inform_data.status.each_pair { |k, v| params[k] = v }
        when :released
          params[:resource_id] = inform_data.resource_id
        when :error, :warn
          params[:reason] = (inform_data.message rescue inform_data)
          logger.__send__(inform_type, (inform_data.message rescue inform_data))
        when :failed
          params[:reason] = inform_data.message
        end

        #unless topic.id.to_s == inform_to
          topic.inform inform_type.to_s.upcase, params
        # else
          # warn "Didn't send inform as topic (#{topic.id} != #{inform_to})"
        # end
        OmfRc::ResourceProxy::MPPublished.inject(Time.now.to_f,
          self.uid, inform_to, "should be message_id") if OmfCommon::Measure.enabled?
      end
      
      
      # If method missing, try the property mash
      def method_missing(method_name, *args)
        warn "Method missing '#{method_name}'"
        if (method_name =~ /request_(.+)/)
          property.key?($1) ? property.send($1) : (raise OmfRc::UnknownPropertyError, method_name.to_s)
        elsif (method_name =~ /configure_(.+)/)
          property.key?($1) ? property.send("[]=", $1, *args) : (raise OmfRc::UnknownPropertyError, method_name.to_s)
        else
          super
        end
      end
         
    end
  end
end