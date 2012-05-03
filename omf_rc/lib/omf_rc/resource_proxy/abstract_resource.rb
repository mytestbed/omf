require 'omf_common'
require 'securerandom'
require 'hashie'

class OmfRc::ResourceProxy::AbstractResource
  attr_accessor :uid, :type, :properties, :comm
  attr_reader :opts, :children, :host

  def initialize(type, opts = nil)
    @opts = Hashie::Mash.new(opts)
    @type = type
    @uid = @opts.uid || SecureRandom.uuid
    @properties = Hashie::Mash.new(@opts.properties)
    @children ||= []

    @comm = OmfCommon::Comm.new(@opts.dsl)
    @host = nil
    register_default_xmpp_callbacks
  end

  # Custom validation rules, extend this to validation specific properties
  def validate
    # Definitely need a type
    raise StandardError if type.nil?
  end

  # Release a child resource
  def release(resource)
    resource.children.each do |child|
      resource.release(child)
    end
    children.delete(resource)
  end

  def add(resource)
    self.children << resource
    resource
  end

  def get_all(conditions)
    children.find_all do |v|
      flag = true
      conditions.each_pair do |key, value|
        flag &&= v.send(key) == value
      end
      flag
    end
  end

  # Creates a new resource in the context of this resource.
  #
  # @param [Hash] opts options to create new resource
  # @option opts [String] :type Type of resource
  # @option opts [Hash] :properties See +configure+ for explanation
  # @return [Object] the newly created resource
  def create(type, opts = nil)
    add(OmfRc::ResourceFactory.new(type, opts))
  end

  # Returns a resource instance if already exists, in the context of this resource, throw exception otherwise.
  #
  # @param [String] resource_uid Resource' global unique identifier
  # @return [Object] resource instance
  def get(resource_uid) # String => Resource
    resource = children.find { |v| v.uid == resource_uid }
    raise Exception, "Resource #{resource_uid} not found" if resource.nil?
    resource
  end

  # Returns a set of child resources based on properties and conditions
  def request(properties, conditions = {})
    get_all(conditions).map do |resource|
      Hashie::Mash.new.tap do |mash|
        properties.each do |key|
          mash[key] ||= resource.request_property(key)
        end
      end
    end
  end

  # Configure this resource.
  #
  # @param [Hash] properties property configuration key value pair
  def configure(properties)
    Hashie::Mash.new(properties).each_pair do |key, value|
      configure_property(key, value)
    end
  end

  def configure_property(property, value)
    properties.send("#{property}=", value)
  end

  def request_property(property)
    properties.send(property)
  end

  def register_default_xmpp_callbacks
    @comm.when_ready do
      logger.info "CONNECTED: #{@comm.jid.inspect}"
      @host = "#{opts.pubsub_host}.#{@comm.jid.domain}"

      @comm.create_node(uid, host) do |s|
        @comm.subscribe(uid, host)
      end
    end

    # Fired when message published
    @comm.node_event :items, :node do |e|
      e.items.each do |item|
        m = OmfCommon::Message.parse(item.payload)
        logger.error "Invalid Message\n#{m.to_xml}" unless m.valid?
        context_id = m.read_element("//context_id").first.content
        logger.info "RECEIVED: #{m.operation.to_s} <Context ID> #{context_id}"

        begin
          case m.operation
          when :create
            @comm.publish(uid, OmfCommon::Message.inform(context_id, 'STATUS').sign, host)
          when :request
            @comm.publish(uid, OmfCommon::Message.inform(context_id, 'STATUS').sign, host)
          when :configure
            @comm.publish(uid, OmfCommon::Message.inform(context_id, 'STATUS').sign, host)
          when :relase
            @comm.publish(uid, OmfCommon::Message.inform(context_id, 'STATUS').sign, host)
          when :inform
          end
        rescue => e
          logger.error "#{e.message}\n#{e.backtrace.join("\n")}"
        end
      end
    end

    # Fired when node created
    @comm.node_event :items do |e|
      logger.info "NODES: #{e.items.map(&:id)}"
    end

    # Generic pubsub event
    @comm.pubsub_event do |e|
      logger.debug "PUBSUB GENERIC EVENT: #{e}"
    end
  end

  def connect
    @comm.connect(opts.user, opts.password, opts.server)
  end

  def disconnect
    @comm.disconnect(host)
  end
end
