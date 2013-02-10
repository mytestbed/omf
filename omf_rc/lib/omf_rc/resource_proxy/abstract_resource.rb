#require 'omf_rc/deferred_process'
require 'omf_rc/omf_error'
require 'securerandom'
require 'hashie'

# OML Measurement Point (MP)
# This MP is for measurements about messages published by the Resource Proxy
class OmfRc::ResourceProxy::MPPublished < OML4R::MPBase
  name :proxy_published
  param :time, :type => :double # Time (s) when this message was published
  param :uid, :type => :string # UID for this Resource Proxy
  param :topic, :type => :string # Pubsub topic to publish this message to
  param :msg_id, :type => :string # Unique ID this message
end

# OML Measurement Point (MP)
# This MP is for measurements about messages received by the Resource Proxy
class OmfRc::ResourceProxy::MPReceived < OML4R::MPBase
  name :proxy_received
  param :time, :type => :double # Time (s) when this message was received
  param :uid, :type => :string # UID for this Resource Proxy
  param :topic, :type => :string # Pubsub topic where this message came from
  param :msg_id, :type => :string # Unique ID this message
end

class OmfRc::ResourceProxy::AbstractResource
  # Time to wait before shutting down event loop, wait for deleting pubsub topics
  DISCONNECT_WAIT = 5
  # Time to wait before releasing resource, wait for deleting pubsub topics
  RELEASE_WAIT = 5

  # @!attribute property
  #   @return [String] the resource's internal meta data storage
  attr_accessor :uid, :hrn, :type, :comm, :property
  attr_reader :opts, :children, :membership

  # Initialisation
  #
  # @param [Symbol] type resource proxy type
  # @param [Hash] opts options to be initialised
  # @option opts [String] :uid Unique identifier
  # @option opts [String] :hrn Human readable name
  # @option opts [String] :dsl Which pubsub DSL to be used for pubsub communication
  # @option opts [String] :user pubsub user id
  # @option opts [String] :password pubsub user password
  # @option opts [String] :server pubsub server domain
  # @option opts [String] :property A hash for keeping internal state
  # @option opts [hash] :instrument A hash for keeping instrumentation-related state
  # @param [Comm] comm communicator instance, pass this to new resource proxy instance if want to use a common communicator instance.
  def initialize(type, opts = nil, comm = nil)
    @opts = Hashie::Mash.new(opts)
    @type = type
    @uid = @opts.uid || SecureRandom.uuid
    @hrn = @opts.hrn && @opts.hrn.to_s
    @children ||= []
    @membership ||= []
    @topics = []

    # FIXME adding hrn to membership too?
    @membership << @hrn if @hrn

    @property = @opts.property || Hashie::Mash.new

    OmfCommon.comm.subscribe(@hrn ? [@uid, @hrn] : @uid) do |t|
      if t.id.to_s == @uid
        @topics << t
      end

      if t.error?
        warn "Could not create topic '#{uid}', will shutdown, trying to clean up old topics. Please start it again once it has been shutdown."
        OmfCommon.comm.disconnect()
      else
        copts = { resource_id: @uid, resource_address: t.address }
        t.inform(:creation_ok, copts.merge(hrn: @hrn), copts)

        t.on_message do |imsg|
          #debug ">>>> #{t.id}: #{imsg}"
          process_omf_message(imsg, t)
        end
      end
    end
  end

  # If method missing, try the property mash
  def method_missing(method_name, *args)
    warn "Method missing: '#{method_name}'"
    if (method_name =~ /request_(.+)/)
      property.key?($1) ? property.send($1) : (raise OmfRc::UnknownPropertyError, method_name.to_s)
    elsif (method_name =~ /configure_(.+)/)
      property.key?($1) ? property.send("[]=", $1, *args) : (raise OmfRc::UnknownPropertyError, method_name.to_s)
    else
      super
    end
  end

  # Return the public 'routable'  address for this resource
  #
  def resource_address()
    @topics[0].address
  end

  def get_binding
    binding
  end

  # Try to clean up pubsub topics, and wait for DISCONNECT_WAIT seconds, then shutdown event machine loop
  def disconnect
    OmfCommon.comm.disconnect(delete_affiliations: true)
    info "Disconnecting #{hrn}(#{uid}) in #{DISCONNECT_WAIT} seconds"
    OmfCommon.eventloop.after(DISCONNECT_WAIT) do
      OmfCommon.comm.disconnect
    end
  end

  # Create a new resource in the context of this resource. This resource becomes parent, and newly created resource becomes child
  #
  # @param (see #initialize)
  def create(type, opts = nil)
    proxy_info = OmfRc::ResourceFactory.proxy_list[type]
    if proxy_info && proxy_info.create_by && !proxy_info.create_by.include?(self.type.to_sym)
      raise StandardError, "Resource #{type} is not designed to be created by #{self.type}"
    end

    before_create(type, opts) if respond_to? :before_create
    new_resource = OmfRc::ResourceFactory.new(type.to_sym, opts, OmfCommon.comm)
    after_create(new_resource) if respond_to? :after_create
    children << new_resource
    new_resource
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

  # Return a list of all properties can be requested and configured
  #
  def request_available_properties(*args)
    Hashie::Mash.new(request: [], configure: []).tap do |mash|
      methods.each do |m|
        mash[$1] << $2.to_sym if m =~ /^(request|configure)_(.+)/ && $2 != "available_properties"
      end
    end
  end

  # Make uid accessible through pubsub interface
  def request_uid(*args)
    uid
  end

  def request_type(*args)
    type
  end

  def configure_type(*args)
    @type = type
  end

  # Make hrn accessible through pubsub interface
  def request_hrn(*args)
    hrn
  end

  alias_method :request_name, :request_hrn
  alias_method :name, :hrn

  # Make hrn configurable through pubsub interface
  def configure_hrn(hrn)
    @hrn = hrn
    @hrn
  end

  alias_method :configure_name, :configure_hrn
  alias_method :name=, :hrn=

  # Make resource part of the group topic, it will overwrite existing membership array
  #
  # @param [String] name of group topic
  # @param [Array] name of group topics
  def configure_membership(*args)
    new_membership = [args[0]].flatten
    new_membership.each do |n_m|
      @membership << n_m unless @membership.include?(n_m)
    end
    @membership.each do |m|
      OmfCommon.comm.subscribe(m) do |stanza|
        if stanza.error?
          warn "Group #{m} disappeared"
          EM.next_tick do
            @membership.delete(m)
          end
        end
      end
    end
    @membership
  end

  # Query resource's membership
  def request_membership(*args)
    @membership
  end

  # Request child resources
  # @return [Hashie::Mash] child resource mash with uid and hrn
  def request_child_resources(*args)
    children.map { |c| Hashie::Mash.new({ uid: c.uid, name: c.hrn }) }
  end

  # Parse omf message and execute as instructed by the message
  #
  # @param [OmfCommon::Message]
  # @param [OmfCommon::Comm::Topic]
  def process_omf_message(message, topic)
    unless message.is_a? OmfCommon::Message
      raise ArgumentError, "Expected OmfCommon::Message, but got '#{message.class}'"
    end

    unless message.valid?
      raise StandardError, "Invalid message received: #{pubsub_item_payload}. Please check protocol schema of version #{OmfCommon::PROTOCOL_VERSION}."
    end

    objects_by_topic(topic.id.to_s).each do |obj|
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
      debug ex.message
      debug ex.backtrace.join("\n")
      return inform(:error, err_resp, topic)
    end

    case message.operation
    when :create
      inform(:creation_ok, response_h, topic)
    when :request, :configure
      inform(:status, response_h, topic)
    when :release
      OmfCommon.eventloop.after(RELEASE_WAIT) do
        inform(:released, response_h, topic)
      end
    end
  end

  # Handling all messages, then delegate them to individual handler
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
    response.resource_id = @uid
    # FIXME At this point topic for new instance has not been created.
    #response.resource_address = new_obj.resource_address rescue new_obj.uid
        
    response[:resource_id] = new_obj.uid
    # FIXME At this point topic for new instance has not been created.
    response[:resource_address] = new_obj.resource_address rescue new_obj.uid

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

    have_unbound = false

    message.each_unbound_request_property do |name|
      puts "NAME>> #{name.inspect}"

      unless allowed_properties.include?(name.to_sym)
        raise ArgumentError, "Unknown 'requestable' property '#{name}'. Allowed properties are: #{allowed_properties.join(', ')}"
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
      inform_data = Hashie::Mash.new(inform_data) if inform_data.class == Hash
      message = OmfCommon::Message.create_inform_message(inform_type.to_s.upcase, inform_data.dup)
    else
      message = inform_data
    end

    message.inform_type = inform_type

    case inform_type
    # FIXME should really just be error or creation_failed
    when :creation_failed, :failed, :error
      # unless inform_data.kind_of? Exception
        # raise ArgumentError, "CREATION_FAILED or ERROR message requires an Exception (or MessageProcessError)"
      # end
    when :creation_ok, :released
      # unless message.resource_id && message.resource_address
        # raise ArgumentError, "CREATION_OK or RELEASED message requires inform_data object respond to resource_id"
      # end
    when :status
      # FIXME what should we check here?
      #if inform_data.property.
      #  raise ArgumentError, "STATUS message requires properties"
      #end
    end

    # FIXME !!!
    #context_id = inform_data.context_id if inform_data.respond_to? :context_id
    #inform_to = inform_data.inform_to if inform_data.respond_to? :inform_to
    #inform_to ||= self.uid

    #i_properties, i_cores = {}, {}

    #i_cores[:context_id] = context_id
    #i_cores[:inform_type] = inform_type.to_s.upcase

    #case inform_type
    #when :creation_ok
    #  i_cores[:resource_id] = inform_data.resource_id
    #  i_cores[:resource_address] = inform_data.resource_id
    #when :status
    #  i_properties = inform_data.status
    #when :released
    #  i_cores[:resource_id] = inform_data.resource_id
    #when :error, :warn
    #  i_cores[:reason] = (inform_data.message rescue inform_data)
    #  logger.__send__(inform_type, (inform_data.message rescue inform_data))
    #when :creation_failed
    #  i_cores[:reason] = inform_data.message
    #end
    #inform_message = OmfCommon::Message.create(:inform, i_properties, i_cores)

    # FIXME !!!

    topic.publish(message)

    OmfRc::ResourceProxy::MPPublished.inject(Time.now.to_f,
      self.uid, inform_to, inform_message.msg_id) if OmfCommon::Measure.enabled?
  end

  private

  # Find resource object based on topic name
  def objects_by_topic(name)
    if name == uid || membership.include?(name)
      objs = [self]
    else
      objs = children.find_all { |v| v.uid == name || v.membership.include?(name)}
    end
  end

  def inform_to_address(obj, publish_to = nil)
    publish_to || obj.uid
  end

  # FIXME delete this
  def _execute_omf_operation(message, obj)
    dp = OmfRc::DeferredProcess.new

    # When successfully executed
    dp.callback do |response|
      response = Hashie::Mash.new(response)
      case response.operation
      when :create
        new_uid = response.resource_id
        OmfCommon.comm.create_topic(new_uid) do
          OmfCommon.comm.subscribe(new_uid) do
            inform(:creation_ok, response)
          end
        end
      when :request, :configure
        inform(:status, response)
      when :release
        EM.add_timer(RELEASE_WAIT) do
          inform(:released, response)
        end
      end
    end

    # When failed
    dp.errback do |e|
      inform(:creation_failed, e)
    end

    # Fire the process
    dp.fire do
      begin
        default_response = {
          operation: message.operation,
          context_id: message.msg_id,
          inform_to: inform_to_address(obj, message.publish_to)
        }

        guard = message.read_element("guard").first

        unless guard.nil? || guard.element_children.empty?
          guard_check = guard.element_children.all? do |g|
            obj.__send__("request_#{g.attr('key')}") == g.content.ducktype
          end
          next nil unless guard_check
        end

        case message.operation
        when :create
          new_name = message.read_property(:name) || message.read_property(:hrn)
          new_opts = opts.dup.merge(uid: nil, hrn: new_name)
          new_obj = obj.create(message.read_property(:type), new_opts)
          message.each_property do |p|
            unless %w(type hrn name).include?(p.attr('key'))
              method_name = "configure_#{p.attr('key')}"
              p_value = message.read_property(p.attr('key'), new_obj.get_binding)
              new_obj.__send__(method_name, p_value)
            end
          end
          new_obj.after_initial_configured if new_obj.respond_to? :after_initial_configured
          default_response.merge(resource_id: new_obj.uid)
        when :request, :configure
          result = Hashie::Mash.new.tap do |mash|
            properties = message.read_element("property")
            if message.operation == :request && properties.empty?
              obj.request_available_properties.request.each do |r_p|
                method_name = "request_#{r_p.to_s}"
                mash[r_p] ||= obj.__send__(method_name)
              end
            else
              properties.each do |p|
                method_name =  "#{message.operation.to_s}_#{p.attr('key')}"
                p_value = message.read_property(p.attr('key'), obj.get_binding)
                mash[p.attr('key')] ||= obj.__send__(method_name, p_value)
              end
            end
          end
          # Always return uid
          result.uid = obj.uid
          default_response.merge(status: result)
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
      rescue => e
        if (e.kind_of? OmfRc::UnknownPropertyError) && (message.operation == :configure || message.operation == :request)
          msg = "Cannot #{message.operation} unknown property '#{e.message}' for resource '#{obj.type}'. Original message fragment: " +
            "'#{message.read_element("property")}'"
          logger.warn msg
          raise OmfRc::MessageProcessError.new(message.context_id, inform_to_address(obj, message.publish_to), msg)
        else
          logger.error e.message
          logger.error e.backtrace.join("\n")
          raise OmfRc::MessageProcessError.new(message.context_id, inform_to_address(obj, message.publish_to), e.message)
        end
      end
    end
  end

end
