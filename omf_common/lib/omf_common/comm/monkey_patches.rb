
#require 'omf_common/message_provider/json/json_message'

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
        #puts "IIIII => #{opts.inspect}"
        @opts = Hashie::Mash.new(opts)
        @type = type
        @uid = @opts.uid || SecureRandom.uuid
        @children ||= []
        @membership ||= []
        if @hrn = @opts.hrn
          @hrn = @hrn.to_s
          @membership << @hrn
        end
        @topics = [] # fill in below
        
        # Really not sure what I'm doing here!
        @property = @opts 
        OmfCommon.comm.subscribe(@hrn ? [@uid, @hrn] : @uid) do |t|
          if t.id.to_s == @uid
            @topics << t 
          end
          if t.error?
              warn "Could not create topic '#{uid}', will shutdown, trying to clean up old topics. Please start it again once it has been shutdown."
              OmfCommon.comm.disconnect()
          else
            t.inform(:created, {resource_id: @uid, resource_address: t.address, hrn: @hrn})

            t.on_message do |imsg|
              #puts ">>>> #{t.id}: #{imsg}"
              process_omf_message(imsg, t)
            end
          end
        end
      end
      
      # Return the publicable 'routable'  address for this resource
      #
      def resource_address()
        @topics[0].address
      end
      
      # Parse omf message and execute as instructed by the message
      #
      def process_omf_message(message, topic)
        unless message.is_a? OmfCommon::Message
          raise "Expected Message, but got '#{message.class}'"
          #message = OmfCommon::Message.new(props.dup)
        end
    #puts "PPP(#{topic.id}|#{uid})-> #{message}"
        objects_by_topic(topic.id.to_s).each do |obj|
    #puts "TTT(#{self})-> #{obj}"
          if OmfCommon::Measure.enabled?
            OmfRc::ResourceProxy::MPReceived.inject(Time.now.to_f, self.uid, topic, message.msg_id) 
          end
          execute_omf_operation(message, obj, topic)
        end
      end
      
      def execute_omf_operation(message, obj, topic)
        begin
          response_h = handle_message(message, obj)
        rescue Exception => ex
          err_resp = message.create_inform_reply_message()
          err_resp[:reason] = ex.to_s
          error "Encountered exception, returning ERROR message"
          debug ex.backtrace.join("\n")
          return inform(:error, err_resp, topic)
        end
          
        case message.operation
        when :create
          inform(:created, response_h, topic)
        when :request, :configure
          inform(:status, response_h, topic)
        when :release
          OmfCommon.eventloop.after(RELEASE_WAIT) do
            inform(:released, response_h, topic)
          end
        end
      end
      
      def handle_message(message, obj)
        response = message.create_inform_reply_message()
        response.inform_to inform_to_address(obj, message.publish_to)
    
        case message.operation
        when :create
          handle_create_message(message, obj, response)
        when :request 
          response = handle_request_message(message, obj, response)        
        when :configure
          handle_configure_message(message, obj, response)        
        when :release
          resource_id = message.resource_id
          released_obj = obj.release(resource_id)
          # TODO: Under what circumstances would 'realease_obj' be NIL
          response[:resource_id] = released_obj ? released_obj.uid : resource_id
          #response[:resource_address] = OmfCommon::CommProvider::Local::Topic.address_for(response[:resource_id])
          response[:resource_address] = released_obj ? released_obj.resource_address() : resource_address()
        when :inform
          nil # We really don't care about inform messages which created from here
        else
          raise StandardError, <<-ERROR
            Invalid message received (Unknown OMF operation #{message.operation}): #{message}.
            Please check protocol schema of version #{OmfCommon::PROTOCOL_VERSION}.
          ERROR
        end
        response
      end
      
      def handle_create_message(message, obj, response)
        new_name = message[:name] || message[:hrn]
        new_opts = {hrn: new_name}
        new_obj = obj.create(message[:type], new_opts)
        exclude = [:type, :hrn, :name]
        message.each_property do |key, value|
          unless exclude.include?(key)
            method_name = "configure_#{key}"
            new_obj.__send__(method_name, value)
          end
        end
        new_obj.after_initial_configured if new_obj.respond_to? :after_initial_configured
        response[:resource_id] = new_obj.uid
        #response[:resource_address] = OmfCommon::CommProvider::Local::Topic.address_for(new_obj.uid)
        response[:resource_address] = new_obj.resource_address()
      end   
      
      def handle_configure_message(message, obj, response)
        message.each_property do |key, value|
          method_name =  "#{message.operation.to_s}_#{key}"
          p_value = message[key]
          response[key] ||= obj.__send__(method_name, p_value)
        end
      end 
      
     def handle_request_message(message, obj, response)
        allowed_properties = obj.request_available_properties.request - [:message]
        # Checking of the request is for us should happen in the more generic GUARD
        # message.each_bound_request_property do |name, value|
          # puts "CHECK: #{name} == #{value}"
          # unless allowed_properties.include?(name)
            # raise ArgumentError, "Unknown 'requestable' property '#{name}'"
          # end
          # method_name = "request_#{name}"
          # return nil unless obj.__send__(method_name) == value
          # response[name] = value # return the constrained value as well
        # end
        # OK, looks like the request is for us
        have_unbound = false
        message.each_unbound_request_property do |name|
          puts "NAME>> #{name.inspect}" 
          
          unless allowed_properties.include?(name)
            raise ArgumentError, "Unknown 'requestable' property '#{name}'"
          end
          method_name = "request_#{name}"
          response[name] = obj.__send__(method_name)
          have_unbound = true
        end
        unless have_unbound
          # return ALL properties
          allowed_properties.each do |name|
            method_name = "request_#{name}"
            response[name] = obj.__send__(method_name)
          end
        end
        response
      end 
      
      # Publish an inform message
      # @param [Symbol] inform_type the type of inform message
      # @param [Hash | Hashie::Mash | Exception | String] inform_data the type of inform message
      def inform(inform_type, inform_data, topic = nil)
        topic ||= @topics.first
        if inform_data.is_a? Hash
          message = OmfCommon::Message.create_inform_message(inform_type, inform_data.dup)
        else
          message = inform_data
        end
        inform_data = Hashie::Mash.new(inform_data) if inform_data.class == Hash
        
        case inform_type
        when :failed
          unless inform_data.kind_of? Exception
            raise ArgumentError, "FAILED message requires an Exception (or MessageProcessError)"
          end
        when :created, :released
          unless message[:resource_id] && message[:resource_address]
            raise ArgumentError, "CREATED or RELEASED message require property 'resource_id' and 'resource_address'"
          end
        when :status
          # unless (message.inform_type ||= :status) == :status 
            # raise ArgumentError, "STATUS message requires a hash represents properties"
          # end
        end

        context_id = inform_data.context_id if inform_data.respond_to? :context_id
        inform_to = inform_data.inform_to if inform_data.respond_to? :inform_to
        inform_to ||= self.uid
    
        # params = {}
        # params[:context_id] = context_id if context_id
        # case inform_type
        # when :created
          # message[:resource_id] = inform_data.resource_id
          # message[:resource_address] = inform_data.resource_id
        # when :status
          # inform_data.status.each_pair { |k, v| params[k] = v }
        # when :released
          # params[:resource_id] = inform_data.resource_id
        # when :error, :warn
          # params[:reason] = (inform_data.message rescue inform_data)
          # logger.__send__(inform_type, (inform_data.message rescue inform_data))
        # when :failed
          # params[:reason] = inform_data.message
        # end

        message.inform_type = inform_type
        topic.publish message #params

        OmfRc::ResourceProxy::MPPublished.inject(Time.now.to_f,
          self.uid, inform_to, "should be message_id") if OmfCommon::Measure.enabled?
      end
      
      # Release a child resource
      #
      # @return [AbstractResource] Relsead child or nil if error
      #
      def release(resource_id)
        if (child = children.find { |v| v.uid.to_s == resource_id.to_s })
          if child.release_self()
            children.delete(child)
            child
          else
            child = nil
          end
        else
          warn "#{resource_id} does not belong to #{self.uid}(#{self.hrn}) - #{children.inspect}"
        end
        child
      end
      
      # Release this resource. Should ONLY be called by parent resource.
      #
      # Return true if successful
      #
      def release_self
        # Release children resource recursively
        children.dup.each do |c|
          if c.release_self
            children.delete(c)
          end
        end
        return false unless children.empty?
        info "Releasing hrn: #{hrn}, uid: #{uid}"
        self.before_release if self.respond_to? :before_release
        props = { 
          resource_id: uid, 
          resource_address: resource_address #OmfCommon::CommProvider::Local::Topic.address_for(uid)
        }
        props[:hrn] = hrn if hrn
        inform :released, props

         
        # clean up topics  
        @topics.each do |t| 
          t.unsubscribe
        end
          
        true        
      end
      
      
      # If method missing, try the property mash
      def method_missing(method_name, *args)
        warn "Method missing '#{method_name}'"
        # if (method_name =~ /request_(.+)/)
          # property.key?($1) ? property.send($1) : (raise OmfRc::UnknownPropertyError, method_name.to_s)
        # elsif (method_name =~ /configure_(.+)/)
          # property.key?($1) ? property.send("[]=", $1, *args) : (raise OmfRc::UnknownPropertyError, method_name.to_s)
        # else
          super
        # end
      end
         
    end
  end


  require 'omf_rc/resource_proxy_dsl'
  module ResourceProxyDSL
    
    DEF_ACCESS = [:configure, :request]
    
    module ClassMethods    
      # Define internal property
      def property(name, opts = {})
        opts = Hashie::Mash.new(opts)
        
        define_method("def_property_#{name}") do |*args, &block|
          self.property[name] ||= opts[:default]
        end
        
        access = opts.access || DEF_ACCESS
        access.each do |a|
          case a
          when :configure
            define_method("configure_#{name}") do |val|
              self.property[name] = val
            end
            
          when :request
            define_method("request_#{name}") do
              self.property[name]
            end
  
          else
            raise "Unnown access type '#{a}'"
          end
        end
      end
    end
  end
  
end