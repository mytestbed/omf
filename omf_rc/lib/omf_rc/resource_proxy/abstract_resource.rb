require 'omf_rc/deferred_process'
require 'omf_rc/omf_error'
require 'securerandom'
require 'hashie'

class OmfRc::ResourceProxy::AbstractResource
  # Time to wait before shutting down event loop, wait for deleting pubsub topics
  DISCONNECT_WAIT = 5
  # Time to wait before releasing resource, wait for deleting pubsub topics
  RELEASE_WAIT = 5

  # @!attribute property
  #   @return [String] the resource's internal meta data storage
  attr_accessor :uid, :hrn, :type, :comm, :property
  attr_reader :opts, :children

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
  # @param [Comm] comm communicator instance, pass this to new resource proxy instance if want to use a common communicator instance.
  def initialize(type, opts = nil, comm = nil)
    @opts = Hashie::Mash.new(opts)
    @type = type
    @uid = @opts.uid || SecureRandom.uuid
    @hrn = @opts.hrn
    @children ||= []

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
      property.send($1) || (raise OmfRc::UnknownPropertyError)
    elsif (method_name =~ /configure_(.+)/)
      property.send($1) ? property.send("[]=", $1, *args) : (raise OmfRc::UnknownPropertyError)
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
  end

  # Request child resources
  # @return [Mash] child resource mash with uid and hrn
  def request_child_resources(*args)
    Hashie::Mash.new.tap do |mash|
      children.each do |c|
        mash[c.uid] ||= c.hrn
      end
    end
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
  end

  private

  # Parse omf message and execute as instructed by the message
  #
  def process_omf_message(pubsub_item_payload, topic)
    dp = OmfRc::DeferredProcess.new

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

    dp.errback do |e|
      inform(:failed, e)
    end

    dp.fire do
      begin
        message = OmfCommon::Message.parse(pubsub_item_payload)

        unless message.valid?
          raise StandardError, "Invalid message received: #{pubsub_item_payload}. Please check protocol schema of version #{OmfCommon::PROTOCOL_VERSION}."
        end

        # Get the context id, which will be included when informing
        context_id = message.read_content("context_id")

        obj = topic == uid ? self : children.find { |v| v.uid == topic }

        raise "Resource disappeard #{topic}" if obj.nil?

        case message.operation
        when :create
          create_opts = opts.dup
          create_opts.uid = nil
          result = obj.create(message.read_property(:type), create_opts)
          message.each_property do |p|
            unless p.attr('key') == 'type'
              method_name =  "configure_#{p.attr('key')}"
              result.__send__(method_name, message.read_property(p.attr('key')))
            end
          end
          result.after_initial_configured if result.respond_to? :after_initial_configured
          { operation: :create, resource_id: result.uid, context_id: context_id, inform_to: uid }
        when :request
          result = Hashie::Mash.new.tap do |mash|
            message.read_element("//property").each do |p|
              method_name =  "request_#{p.attr('key')}"
              mash[p.attr('key')] ||= obj.__send__(method_name, message.read_property(p.attr('key')))
            end
          end
          { operation: :request, status: result, context_id: context_id, inform_to: obj.uid }
        when :configure
          result = Hashie::Mash.new.tap do |mash|
            message.read_element("//property").each do |p|
              method_name =  "configure_#{p.attr('key')}"
              mash[p.attr('key')] ||= obj.__send__(method_name, message.read_property(p.attr('key')))
            end
          end
          { operation: :configure, status: result, context_id: context_id, inform_to: obj.uid }
        when :release
          resource_id = message.resource_id
          { operation: :release, resource_id: obj.release(resource_id).uid, context_id: context_id, inform_to: obj.uid }
        when :inform
          # We really don't care about inform messages which created from here
          nil
        else
          raise "Unknown OMF operation #{message.operation}"
        end
      rescue => e
        if (e.kind_of? OmfRc::UnknownPropertyError) && (message.operation == :configure || message.operation == :request)
          msg = "Cannot #{message.operation} unknown property "+
            "'#{message.read_element("//property")}' for resource '#{type}'"
          logger.warn msg
          raise OmfRc::MessageProcessError.new(context_id, obj.uid, msg)
        else
          logger.error e.message
          logger.error e.backtrace.join("\n")
          raise OmfRc::MessageProcessError.new(context_id, obj.uid, e.message)
        end
      end
    end
  end
end
