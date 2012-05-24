require 'omf_common'
require 'omf_rc/deferred_process'
require 'securerandom'
require 'hashie'

class OmfRc::ResourceProxy::AbstractResource
  DISCONNECT_WAIT = 5
  attr_accessor :uid, :hrn, :type, :properties, :comm
  attr_reader :opts, :children, :host

  def initialize(type, opts = nil, comm = nil)
    @opts = Hashie::Mash.new(opts)
    @type = type
    @uid = @opts.uid || SecureRandom.uuid
    @hrn = @opts.hrn
    @properties = Hashie::Mash.new(@opts.properties)
    @children ||= []
    @host = nil

    @comm = comm || OmfCommon::Comm.new(@opts.dsl)
    # Fire when connection to pubsub server established
    @comm.when_ready do
      logger.info "CONNECTED: #{@comm.jid.inspect}"
      @host = "#{@opts.pubsub_host}.#{@comm.jid.domain}"

      # Once connection established, create a pubsub node, then subscribe to it
      @comm.create_node(uid, host) do |s|
        # Creating node failed, no point to continue; clean up and disconnect
        # Otherwise go subscribe to this pubsub node
        s.error? ? disconnect : @comm.subscribe(uid, host)
      end
    end

    # Fire when message published
    @comm.node_event do |e|
      logger.info e.node
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

  def disconnect
    @comm.pubsub.affiliations(host) do |a|
      my_pubsub_nodes = a[:owner] ? a[:owner].size : 0
      if my_pubsub_nodes > 0
        logger.info "Cleaning #{my_pubsub_nodes} pubsub node(s)"
        a[:owner].each { |node| @comm.delete_node(node, host) }
      else
        logger.info "Disconnecting now"
        @comm.disconnect(host)
      end
    end
    EM.add_timer(DISCONNECT_WAIT) do
      logger.info "Disconnecting in #{DISCONNECT_WAIT} seconds"
      @comm.disconnect(host)
    end
  end

  # Create a new resource in the context of this resource. This resource becomes parent, and newly created resource becomes child
  #
  def create(context_id, type, opts = nil)
    new_resource = OmfRc::ResourceFactory.new(type.to_sym, opts, @comm)
    children << new_resource
    [new_resource, context_id]
  end

  # Release a resource
  #
  def release
  end

  private

  # Parse omf message and execute as instructed by the message
  #
  def process_omf_message(pubsub_item_payload, node)
    dp = OmfRc::DeferredProcess.new

    dp.callback do |result|
      if result && result[0].class == self.class
        context_id = result[1]
        @comm.create_node(result[0].uid, host) do
          @comm.subscribe(result[0].uid, host) do
            inform_msg = OmfCommon::Message.inform(context_id, 'CREATED') do |i|
              i.element('resource_id', result[0].uid)
              i.element('resource_address', result[0].uid)
            end.sign
            @comm.publish(uid, inform_msg, host)
          end
        end
      end
    end

    dp.errback do |e|
      logger.error e.message
      logger.error e.backtrace.join("\n")
    end

    dp.fire do
      message = OmfCommon::Message.parse(pubsub_item_payload)
      # Get the context id, which will be included when informing
      context_id = message.read_content("//context_id")

      obj = node == uid ? self : children.find { |v| v.uid == node }

      case message.operation
      when :create
        create_opts = opts.dup
        create_opts.uid = nil
        create(context_id, message.read_property(:type), create_opts)
      when :request
        nil
      when :configure
        nil
      when :release
        nil
      else
        nil
      end
    end
  end
end
