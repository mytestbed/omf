require 'omf_rc/deferred_process'
require 'omf_rc/omf_error'
require 'securerandom'
require 'hashie'

class OmfRc::ResourceProxy::MPPublished < OML4R::MPBase
  name :proxy_published
  param :time, :type => :int32
  param :uid, :type => :string
  param :topic, :type => :string
  param :msg_id, :type => :string
end

class OmfRc::ResourceProxy::MPReceived < OML4R::MPBase
  name :proxy_received
  param :time, :type => :int32
  param :uid, :type => :string
  param :topic, :type => :string
  param :msg_id, :type => :string
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
    @hrn = @opts.hrn
    @children ||= []
    @membership ||= []

    @property = @opts.property || Hashie::Mash.new

    @comm = comm || OmfCommon::Comm.new(@opts.dsl)
    # Fire when connection to pubsub server established
    @comm.when_ready do
      logger.info "CONNECTED: #{@comm.jid.inspect}"

      # Once connection established, create a pubsub topic, then subscribe to it
      @comm.create_topic(uid) do |s|
        # Creating topic failed, no point to continue; clean up and disconnect
        # Otherwise go subscribe to this pubsub topic
        s.error? ? disconnect : @comm.subscribe(uid)
      end
    end

    # Fire when message published
    @comm.topic_event do |e|
      e.items.each do |item|
        process_omf_message(item.payload, e.node)
      end
    end

    # Generic pubsub event
    @comm.pubsub_event do |e|
      logger.debug "PUBSUB GENERIC EVENT: #{e}"
    end
  end

  # If method missing, try the property mash
  def method_missing(method_name, *args)
    if (method_name =~ /request_(.+)/)
      property.key?($1) ? property.send($1) : (raise OmfRc::UnknownPropertyError)
    elsif (method_name =~ /configure_(.+)/)
      property.key?($1) ? property.send("[]=", $1, *args) : (raise OmfRc::UnknownPropertyError)
    else
      super
    end
  end

  # Connect to pubsub server
  def connect
    @comm.connect(opts.user, opts.password, opts.server)
  end

  # Try to clean up pubsub topics, and wait for DISCONNECT_WAIT seconds, then shutdown event machine loop
  def disconnect
    @comm.affiliations do |a|
      my_pubsub_topics = a[:owner] ? a[:owner].size : 0
      if my_pubsub_topics > 0
        logger.info "Cleaning #{my_pubsub_topics} pubsub topic(s)"
        a[:owner].each { |topic| @comm.delete_topic(topic) }
      else
        logger.info "Disconnecting now"
        @comm.disconnect
      end
    end
    logger.info "Disconnecting in #{DISCONNECT_WAIT} seconds"
    EM.add_timer(DISCONNECT_WAIT) do
      @comm.disconnect
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
    new_resource = OmfRc::ResourceFactory.new(type.to_sym, opts, @comm)
    after_create(new_resource) if respond_to? :after_create
    children << new_resource
    new_resource
  end

  # Release a resource
  #
  def release(resource_id)
    obj = children.find { |v| v.uid == resource_id }
    raise StandardError, "Resource #{resource_id} could not be found" if obj.nil?

    # Release children resource recursively
    obj.children.each do |c|
      obj.release(c.uid)
    end
    obj.before_release if obj.respond_to? :before_release

    children.delete(obj)
  end

  # Return a list of all properties can be requested and configured
  #
  def request_available_properties(*args)
    Hashie::Mash.new(request: [], configure: []).tap do |mash|
      methods.each do |m|
        mash[$1] << $2.to_sym if m =~ /(request|configure)_(.+)/ && $2 != "available_properties"
      end
    end
  end

  # Make uid accessible through pubsub interface
  def request_uid(*args)
    uid
  end

  # Make hrn accessible through pubsub interface
  def request_hrn(*args)
    hrn
  end

  # Make hrn configurable through pubsub interface
  def configure_hrn(hrn)
    @hrn = hrn
    @hrn
  end

  # Make resource part of the group topic, it will overwrite existing membership array
  #
  # @param [String] name of group topic
  # @param [Array] name of group topics
  def configure_membership(*args)
    new_membership = [args[0]].flatten
    @membership = new_membership
    @membership.each do |m|
      @comm.subscribe(m)
    end
    @membership
  end

  # Request child resources
  # @return [Hashie::Mash] child resource mash with uid and hrn
  def request_child_resources(*args)
    children.map { |c| Hashie::Mash.new({ uid: c.uid, name: c.hrn }) }
  end

  # Publish an inform message
  # @param [Symbol] inform_type the type of inform message
  # @param [Hash | Hashie::Mash | Exception | String] inform_data the type of inform message
  def inform(inform_type, inform_data)
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

    inform_message = OmfCommon::Message.inform(inform_type.to_s.upcase, context_id) do |i|
      case inform_type
      when :created
        i.element('resource_id', inform_data.resource_id)
        i.element('resource_address', inform_data.resource_id)
      when :status
        inform_data.status.each_pair { |k, v| i.property(k, v) }
      when :released
        i.element('resource_id', inform_data.resource_id)
      when :error, :warn
        i.element("reason", (inform_data.message rescue inform_data))
        logger.__send__(inform_type, (inform_data.message rescue inform_data))
      when :failed
        i.element("reason", inform_data.message)
      end
    end
    @comm.publish(inform_to, inform_message)
    OmfRc::ResourceProxy::MPPublished.inject(Time.now.to_i,
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

  # Parse omf message and execute as instructed by the message
  #
  def process_omf_message(pubsub_item_payload, topic)
    message = OmfCommon::Message.parse(pubsub_item_payload)

    unless message.valid?
      raise StandardError, "Invalid message received: #{pubsub_item_payload}. Please check protocol schema of version #{OmfCommon::PROTOCOL_VERSION}."
    end

    objects_by_topic(topic).each do |obj|
      OmfRc::ResourceProxy::MPReceived.inject(Time.now.to_i,
        self.uid, topic, message.msg_id) if OmfCommon::Measure.enabled?
      execute_omf_operation(message, obj)
    end
  end

  def execute_omf_operation(message, obj)
    dp = OmfRc::DeferredProcess.new

    # When successfully executed
    dp.callback do |response|
      response = Hashie::Mash.new(response)
      case response.operation
      when :create
        new_uid = response.resource_id
        @comm.create_topic(new_uid) do
          @comm.subscribe(new_uid) do
            inform(:created, response)
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
      inform(:failed, e)
    end

    # Fire the process
    dp.fire do
      begin
        default_response = {
          operation: message.operation,
          context_id: message.context_id,
          inform_to: inform_to_address(obj, message.publish_to)
        }

        case message.operation
        when :create
          new_opts = opts.dup.merge(uid: nil)
          new_obj = obj.create(message.read_property(:type), new_opts)
          message.each_property do |p|
            unless p.attr('key') == 'type'
              method_name = "configure_#{p.attr('key')}"
              new_obj.__send__(method_name, message.read_property(p.attr('key')))
            end
          end
          new_obj.after_initial_configured if new_obj.respond_to? :after_initial_configured
          default_response.merge(resource_id: new_obj.uid)
        when :request, :configure
          result = Hashie::Mash.new.tap do |mash|
            properties = message.read_element("//property")
            if message.operation == :request && properties.empty?
              obj.request_available_properties.request.each do |r_p|
                method_name = "request_#{r_p.to_s}"
                mash[r_p] ||= obj.__send__(method_name)
              end
            else
              properties.each do |p|
                method_name =  "#{message.operation.to_s}_#{p.attr('key')}"
                mash[p.attr('key')] ||= obj.__send__(method_name, message.read_property(p.attr('key')))
              end
            end
          end
          default_response.merge(status: result)
        when :release
          resource_id = message.resource_id
          default_response.merge(resource_id: obj.release(resource_id).uid)
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
          msg = "Cannot #{message.operation} unknown property "+
            "'#{message.read_element("//property")}' for resource '#{type}'"
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
