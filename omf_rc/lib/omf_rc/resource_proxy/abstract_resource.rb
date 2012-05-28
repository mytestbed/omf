require 'omf_common'
require 'omf_rc/deferred_process'
require 'omf_rc/message_process_error'
require 'securerandom'
require 'hashie'

class OmfRc::ResourceProxy::AbstractResource
  DISCONNECT_WAIT = 5
  RELEASE_WAIT = 5
  attr_accessor :uid, :hrn, :type, :comm
  attr_reader :opts, :children, :host

  # Initialisation
  #
  # @param [Symbol] type resource proxy type
  # @param [Hash] opts options to be initialised
  # @option opts [String] :uid Unique identifier
  # @option opts [String] :hrn Human readable name
  # @option opts [String] :pubsub_host pubsub server subdomain, default to 'pubsub'
  # @option opts [String] :dsl Which pubsub DSL to be used for pubsub communication
  # @option opts [String] :user pubsub user id
  # @option opts [String] :password pubsub user password
  # @option opts [String] :server pubsub server domain
  # @param [Comm] comm communicator instance, pass this to new resource proxy instance if want to use a common communicator instance.
  def initialize(type, opts = nil, comm = nil)
    @opts = Hashie::Mash.new(opts)
    @type = type
    @uid = @opts.uid || SecureRandom.uuid
    @hrn = @opts.hrn
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

  # Try to clean up pubsub nodes, and wait for DISCONNECT_WAIT seconds, then shutdown event machine loop
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
    logger.info "Disconnecting in #{DISCONNECT_WAIT} seconds"
    EM.add_timer(DISCONNECT_WAIT) do
      @comm.disconnect(host)
    end
  end

  # Create a new resource in the context of this resource. This resource becomes parent, and newly created resource becomes child
  #
  # @param (see #initialize)
  def create(type, opts = nil)
    new_resource = OmfRc::ResourceFactory.new(type.to_sym, opts, @comm)
    children << new_resource
    new_resource
  end

  # Release a resource
  #
  def release
    pubsub_nodes_left = []
    children.each do |c|
      c.before_release if c.respond_to? :before_release
      pubsub_nodes_left << c.uid
      c.freeze
    end.clear
    before_release if respond_to? :before_release
    freeze
    pubsub_nodes_left
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
  def confgure_hrn(hrn)
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

  # Parse omf message and execute as instructed by the message
  #
  def process_omf_message(pubsub_item_payload, node)
    dp = OmfRc::DeferredProcess.new

    dp.callback do |end_result|
      if end_result
        case end_result[:operation]
        when :create
          new_uid = end_result[:result]
          @comm.create_node(new_uid, host) do
            @comm.subscribe(new_uid, host) do
              inform_msg = OmfCommon::Message.inform(end_result[:context_id], 'CREATED') do |i|
                i.element('resource_id', new_uid)
                i.element('resource_address', new_uid)
              end.sign
              @comm.publish(end_result[:inform_to], inform_msg, host)
            end
          end
        when :request
          inform_msg = OmfCommon::Message.inform(end_result[:context_id], 'STATUS') do |i|
            end_result[:result].each_pair do |k, v|
              i.property(k) { |p| p.element('current', v) }
            end
          end.sign
          @comm.publish(end_result[:inform_to], inform_msg, host)

        when :configure
          inform_msg = OmfCommon::Message.inform(end_result[:context_id], 'STATUS') do |i|
            end_result[:result].each_pair do |k, v|
              i.property(k) { |p| p.element('current', v) }
            end
          end.sign
          @comm.publish(end_result[:inform_to], inform_msg, host)
        when :release
          inform_msg = OmfCommon::Message.inform(end_result[:context_id], 'RELEASED') do |i|
            i.element('resource_id', end_result[:inform_to])
          end

          end_result[:result].each do |n|
            @comm.delete_node(n, host)
          end

          EM.add_timer(RELEASE_WAIT) do
            @comm.publish(end_result[:inform_to], inform_msg, host)
          end
        end
      end
    end

    dp.errback do |e|
      inform_msg = OmfCommon::Message.inform(e.context_id, 'FAILED') do |i|
        i.element("error_message", e.message)
      end.sign
      @comm.publish(e.inform_to, inform_msg, host)
    end

    dp.fire do
      message = OmfCommon::Message.parse(pubsub_item_payload)
      # Get the context id, which will be included when informing
      context_id = message.read_content("context_id")

      obj = node == uid ? self : children.find { |v| v.uid == node }

      begin
        raise "Resource disappeard #{node}" if obj.nil?

        case message.operation
        when :create
          create_opts = opts.dup
          create_opts.uid = nil
          result = obj.create(message.read_property(:type), create_opts)
          { operation: :create, result: result.uid, context_id: context_id, inform_to: uid }
        when :request
          result = Hashie::Mash.new.tap do |mash|
            message.read_element("//property").each do |p|
              method_name =  "request_#{p.attr('key')}"
              if obj.respond_to? method_name
                mash[p.attr('key')] ||= obj.send(method_name)
              end
            end
          end
          { operation: :request, result: result, context_id: context_id, inform_to: obj.uid }
        when :configure
          result = Hashie::Mash.new.tap do |mash|
            message.read_element("//property").each do |p|
              method_name =  "configure_#{p.attr('key')}"
              if obj.respond_to? method_name
                mash[p.attr('key')] ||= obj.send(method_name, p.content)
              end
            end
          end
          { operation: :configure, result: result, context_id: context_id, inform_to: obj.uid }
        when :release
          { operation: :release, result: obj.release, context_id: context_id, inform_to: obj.uid }
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
