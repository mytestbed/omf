require 'omf_rc/deferred_process'
require 'omf_rc/message_process_error'
require 'securerandom'
require 'hashie'

class OmfRc::ResourceProxy::AbstractResource
  # Time to wait before shutting down event loop, wait for deleting pubsub topics
  DISCONNECT_WAIT = 5
  # Time to wait before releasing resource, wait for deleting pubsub topics
  RELEASE_WAIT = 5
  # Inform message types mapping, e.g. create will expect responding with 'CREATED'
  INFORM_TYPES = { create: 'CREATED', request: 'STATUS', configure: 'STATUS', release: 'RELEASED', error: 'FAILED'}

  # @!attribute property
  #   @return [String] the resource's internal meta data storage
  attr_accessor :uid, :hrn, :type, :comm, :property
  attr_reader :opts, :children, :host

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
    @host = nil
    @property = @opts.property || Hashie::Mash.new

    @comm = comm || OmfCommon::Comm.new(@opts.dsl)
    # Fire when connection to pubsub server established
    @comm.when_ready do
      logger.info "CONNECTED: #{@comm.jid.inspect}"
      @host = @comm.jid.domain

      # Once connection established, create a pubsub topic, then subscribe to it
      @comm.create_topic(uid, host) do |s|
        # Creating topic failed, no point to continue; clean up and disconnect
        # Otherwise go subscribe to this pubsub topic
        s.error? ? disconnect : @comm.subscribe(uid, host)
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

  # Connect to pubsub server
  def connect
    @comm.connect(opts.user, opts.password, opts.server)
  end

  # Try to clean up pubsub topics, and wait for DISCONNECT_WAIT seconds, then shutdown event machine loop
  def disconnect
    @comm.affiliations(host) do |a|
      my_pubsub_topics = a[:owner] ? a[:owner].size : 0
      if my_pubsub_topics > 0
        logger.info "Cleaning #{my_pubsub_topics} pubsub topic(s)"
        a[:owner].each { |topic| @comm.delete_topic(topic, host) }
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
    before_create if respond_to? :before_create
    new_resource = OmfRc::ResourceFactory.new(type.to_sym, opts, @comm)
    children << new_resource
    new_resource
  end

  # Release a resource
  #
  def release(resource_id)
    obj = children.find { |v| v.uid == resource_id }

    # Release children resource recursively
    obj.children.each do |c|
      obj.release(c.uid)
    end
    obj.before_release if obj.respond_to? :before_release

    children.delete(obj)
  end

  # Return a list of all properties can be requested and configured
  #
  def request_available_properties
    Hashie::Mash.new(request: [], configure: []).tap do |mash|
      methods.each do |m|
        mash[$1] << $2.to_sym if m =~ /(request|configure)_(.+)/ && $2 != "available_properties"
      end
    end
  end

  # Make uid accessible through pubsub interface
  def request_uid
    uid
  end

  # Make hrn accessible through pubsub interface
  def request_hrn
    hrn
  end

  # Make hrn configurable through pubsub interface
  def configure_hrn(hrn)
    @hrn = hrn
  end

  # Request child resources
  # @return [Mash] child resource mash with uid and hrn
  def request_child_resources
    Hashie::Mash.new.tap do |mash|
      children.each do |c|
        mash[c.uid] ||= c.hrn
      end
    end
  end

  private

  def publish_inform(response)
    if response.kind_of? StandardError
      operation, context_id, inform_to, message = :error, response.context_id, response.inform_to, response.message
    else
      operation, result, context_id, inform_to = response.operation, response.result, response.context_id, response.inform_to
    end

    inform_message = OmfCommon::Message.inform(INFORM_TYPES[operation], context_id) do |i|
      case operation
      when :create
        i.element('resource_id', result)
        i.element('resource_address', result)
      when :request, :configure
        result.each_pair { |k, v| i.property(k, v) }
      when :release
        i.element('resource_id', result)
      when :error
        i.element("error_message", message)
      end
    end
    @comm.publish(inform_to, inform_message, host)
  end

  # Parse omf message and execute as instructed by the message
  #
  def process_omf_message(pubsub_item_payload, topic)
    dp = OmfRc::DeferredProcess.new

    dp.callback do |response|
      response = Hashie::Mash.new(response)
      case response.operation
      when :create
        new_uid = response.result
        @comm.create_topic(new_uid, host) do
          @comm.subscribe(new_uid, host) do
            publish_inform(response)
          end
        end
      when :request, :configure
        publish_inform(response)
      when :release
        EM.add_timer(RELEASE_WAIT) do
          publish_inform(response)
        end
      end
    end

    dp.errback do |e|
      publish_inform(e)
    end

    dp.fire do
      message = OmfCommon::Message.parse(pubsub_item_payload)
      # Get the context id, which will be included when informing
      context_id = message.read_content("context_id")

      obj = topic == uid ? self : children.find { |v| v.uid == topic }

      begin
        raise "Resource disappeard #{topic}" if obj.nil?

        case message.operation
        when :create
          create_opts = opts.dup
          create_opts.uid = nil
          result = obj.create(message.read_property(:type), create_opts)
          message.read_element("//property").each do |p|
            unless p.attr('key') == 'type'
              method_name =  "configure_#{p.attr('key')}"
              result.__send__(method_name, p.content) if result.respond_to? method_name
            end
          end
          { operation: :create, result: result.uid, context_id: context_id, inform_to: uid }
        when :request
          result = Hashie::Mash.new.tap do |mash|
            message.read_element("//property").each do |p|
              method_name =  "request_#{p.attr('key')}"
              if obj.respond_to? method_name
                mash[p.attr('key')] ||= obj.__send__(method_name, message.read_property(p.attr('key')))
              end
            end
          end
          { operation: :request, result: result, context_id: context_id, inform_to: obj.uid }
        when :configure
          result = Hashie::Mash.new.tap do |mash|
            message.read_element("//property").each do |p|
              method_name =  "configure_#{p.attr('key')}"
              if obj.respond_to? method_name
                mash[p.attr('key')] ||= obj.__send__(method_name, message.read_property(p.attr('key')))
              end
            end
          end
          { operation: :configure, result: result, context_id: context_id, inform_to: obj.uid }
        when :release
          resource_id = message.read_content("resource_id")
          { operation: :release, result: obj.release(resource_id), context_id: context_id, inform_to: obj.uid }
        when :inform
          # We really don't care about inform messages which created from here
          nil
        else
          raise "Unknown OMF operation #{message.operation}"
        end
      rescue => e
        logger.error e.message
        logger.error e.backtrace.join("\n")
        raise OmfRc::MessageProcessError.new(context_id, obj.uid, e.message)
      end
    end
  end
end
