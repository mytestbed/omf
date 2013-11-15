# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'omf_rc/omf_error'
require 'securerandom'
require 'hashie'
require 'monitor'

# OML Measurement Point (MP)
# This MP is for measurements about messages published by the Resource Proxy
class OmfRc::ResourceProxy::MPPublished < OML4R::MPBase
  name :proxy_published
  param :time, :type => :double # Time (s) when this message was published
  param :uid, :type => :string # UID for this Resource Proxy
  param :topic, :type => :string # Pubsub topic to publish this message to
  param :mid, :type => :string # Unique ID this message
end

# OML Measurement Point (MP)
# This MP is for measurements about messages received by the Resource Proxy
class OmfRc::ResourceProxy::MPReceived < OML4R::MPBase
  name :proxy_received
  param :time, :type => :double # Time (s) when this message was received
  param :uid, :type => :string # UID for this Resource Proxy
  param :topic, :type => :string # Pubsub topic where this message came from
  param :mid, :type => :string # Unique ID this message
end

# @note Suppose you have read the {file:doc/DEVELOPERS.mkd DEVELOPERS GUIDE} which explains the basic the resource controller system.
#
# This is the abstract resource proxy class, which provides the base of all proxy implementations. When creating new resource instances, this abstract class will always be initialised first and then extended by one of the specific resource proxy modules.
#
# Instead of initialise abstract resource directly, use {OmfRc::ResourceFactory Resource Factory}'s methods.
#
# @example Creating resource using factory method
#   OmfRc::ResourceFactory.create(:node, uid: 'node01')
#
# Proxy documentation has grouped FRCP API methods for your convenience.
#
# We follow a simple naming convention for request/configure properties.
#
#   request_xxx() indicates property 'xxx' can be requested using FRCP REQUEST message.
#
#   configure_xxx(value) indicates property 'xxx' can be configured with 'value' using FRCP CONFIGURE message.
#
# Currently official OMF RC gem contains following resource proxies:
#
# Representing physical/virtual machine
# * {OmfRc::ResourceProxy::Node Node}
#
# Executing OML enabled application and monitor output
# * {OmfRc::ResourceProxy::Application Application}
#
# Configuring network interfaces
# * {OmfRc::ResourceProxy::Net Net}
# * {OmfRc::ResourceProxy::Wlan Wlan}
#
# Installing packages
# * {OmfRc::ResourceProxy::Package Package}
#
# Creating virtual machines
# * {OmfRc::ResourceProxy::VirtualMachineFactory VirtualMachineFactory}
# * {OmfRc::ResourceProxy::VirtualMachine VirtualMachine}
#
# @see OmfRc::ResourceFactory
# @see OmfRc::ResourceProxyDSL
#
class OmfRc::ResourceProxy::AbstractResource
  include MonitorMixin
  include OmfRc::ResourceProxyDSL

  # Time to wait before releasing resource, wait for deleting pubsub topics
  RELEASE_WAIT = 5

  DEFAULT_CREATION_OPTS = {
    suppress_create_message: false,
    create_children_resources: true
  }

  attr_accessor :uid, :hrn, :type, :property, :certificate
  attr_reader :opts, :children, :membership, :creation_opts, :membership_topics, :topics

  # Initialisation
  #
  # @param [Symbol] type resource proxy type
  #
  # @param [Hash] opts options to be initialised
  # @option opts [String] :uid Unique identifier
  # @option opts [String] :hrn Human readable name
  # @option opts [Hash] :instrument A hash for keeping instrumentation-related state
  # @option opts [OmfCommon::Auth::Certificate] :certificate The certificate for this resource
  #
  # @param [Hash] creation_opts options to control the resource creation process
  # @option creation_opts [Boolean] :suppress_create_message Don't send an initial CREATION.OK Inform message
  # @option creation_opts [Boolean] :create_children_resources Immediately create 'known' children resources, such as interfaces on nodes
  #
  def initialize(type, opts = {}, creation_opts = {}, &creation_callback)
    super()

    @opts = Hashie::Mash.new(opts)
    @creation_opts = Hashie::Mash.new(DEFAULT_CREATION_OPTS.merge(creation_opts))

    @type = type
    @uid = (@opts.delete(:uid) || SecureRandom.uuid).to_s
    @hrn = @opts.delete(:hrn)
    @hrn = @hrn.to_s if @hrn

    @children = []
    @membership = []
    @topics = []
    @membership_topics = {}
    @property = Hashie::Mash.new

    OmfCommon.comm.subscribe(@uid) do |t|
      @topics << t

      if t.error?
        warn "Could not create topic '#{uid}', will shutdown, trying to clean up old topics. Please start it again once it has been shutdown."
        OmfCommon.comm.disconnect()
      else
        begin
          # Setup authentication related properties
          if (@certificate = @opts.delete(:certificate))
            OmfCommon::Auth::CertificateStore.instance.register(@certificate, t.address)
          else
            if (pcert = @opts.delete(:parent_certificate))
              @certificate = pcert.create_for(resource_address, @type, t.address)
            end
          end

          # Extend resource with Resource Module, can be obtained from Factory
          emodule = OmfRc::ResourceFactory.proxy_list[@type].proxy_module || "OmfRc::ResourceProxy::#{@type.camelize}".constantize
          self.extend(emodule)
          # Initiate property hash with default property values
          self.methods.each do |m|
            self.__send__(m) if m =~ /default_property_(.+)/
          end
          # Bootstrap initial configure, this should handle membership too
          init_configure(self, @opts)
          # Execute resource before_ready hook if any
          call_hook :before_ready, self

          # Prepare init :creation_ok message
          copts = { src: self.resource_address }
          copts[:cert] = @certificate.to_pem_compact if @certificate
          cprops = @property
          cprops[:res_id] = self.resource_address
          add_prop_status_to_response(self, @opts.keys, cprops)

          # Then send inform message to itself, with all resource options' current values.
          t.inform(:creation_ok, cprops, copts) unless creation_opts[:suppress_create_message]

          t.on_message(@uid) do |imsg|
            process_omf_message(imsg, t)
          end

          creation_callback.call(self) if creation_callback
        rescue => e
          error "Encountered exception: #{e.message}, returning ERROR message"
          debug e.backtrace.join("\n")
          t.inform(:creation_failed,
                   { reason: e.message },
                   { src: self.resource_address })
        end
      end
    end
  end

  # Return resource' pubsub topic it has subscribed.
  def resource_topic
    if @topics.empty?
      raise TopicNotSubscribedError, "Resource '#{@uid}' has not subscribed to any topics"
    end
    @topics[0]
  end

  # Return the public 'routable' address for this resource or nil if not known yet.
  #
  def resource_address
    resource_topic.address
  end

  # Get binding of current object, used for ERB eval
  def get_binding
    binding
  end

  # Disconnect using communicator
  def disconnect
    OmfCommon.comm.disconnect
  end

  # Create a new resource in the context of this resource. This resource becomes parent, and newly created resource becomes child
  #
  # @param (see #initialize)
  # @return [AbstractResource] new resource has been created
  def create(type, opts = {}, creation_opts = {}, &creation_callback)
    unless request_supported_children_type.include?(type.to_sym)
      raise StandardError, "Resource #{type} is not designed to be created by #{self.type}"
    end

    opts[:parent_certificate] = @certificate if @certificate
    opts[:parent] = self

    call_hook(:before_create, self, type, opts)

    new_resource = OmfRc::ResourceFactory.create(type.to_sym, opts, creation_opts, &creation_callback)

    call_hook(:after_create, self, new_resource)

    self.synchronize do
      children << new_resource
    end
    new_resource
  end

  # Release a child resource
  #
  # @return [AbstractResource] Released child or nil if error
  def release(res_id)
    if (child = children.find { |v| v.uid.to_s == res_id.to_s })
      if child.release_self()
        self.synchronize do
          children.delete(child)
        end
        child
      else
        child = nil
      end
      debug "#{child.uid} released"
    else
      debug "#{res_id} does not belong to #{self.uid}(#{self.hrn}) - #{children.map(&:uid).inspect}"
    end
    child
  end

  # Release this resource. Should ONLY be called by parent resource.
  #
  # @return [Boolean] true if successful
  def release_self
    # Release children resource recursively
    children.each do |c|
      if c.release_self
        self.synchronize do
          children.delete(c)
        end
      end
    end

    return false unless children.empty?

    info "Releasing hrn: #{hrn}, uid: #{uid}"

    call_hook(:before_release, self)

    props = {
      res_id: resource_address
    }
    props[:hrn] = hrn if hrn
    inform :released, props

    # clean up topics
    @topics.each do |t|
      t.unsubscribe(@uid)
    end

    @membership_topics.each_value do |t|
      if t.respond_to? :delete_on_message_cbk_by_id
        t.delete_on_message_cbk_by_id(@uid)
      end
      t.unsubscribe(@uid)
    end

    true
  end

  # @!macro group_request
  #
  # Return a list of child resources this resource can create
  #
  # @return [Array<Symbol>]
  def request_supported_children_type(*args)
    OmfRc::ResourceFactory.proxy_list.reject { |v| v == @type.to_s }.find_all do |k, v|
      (v.create_by && v.create_by.include?(@type.to_sym)) || v.create_by.nil?
    end.map(&:first).map(&:to_sym)
  end

  # Return a list of all properties can be requested and configured
  #
  # @example
  #   { request: [:ip_addr, :frequency], configure: [:ip_address] }
  #
  # @return [Hashie::Mash]
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

  # Make type accessible through pubsub interface
  def request_type(*args)
    type
  end

  # Make hrn accessible through pubsub interface
  def request_hrn(*args)
    hrn
  end

  alias_method :request_name, :request_hrn
  alias_method :name, :hrn
  alias_method :name=, :hrn=

  # Query resource's membership
  def request_membership(*args)
    @membership
  end

  # Request child resources
  #
  # @return [Hashie::Mash] child resource mash with uid and hrn
  def request_child_resources(*args)
    #children.map { |c| Hashie::Mash.new({ uid: c.uid, name: c.hrn }) }
    children.map { |c| c.to_hash }
  end

  # @!endgroup
  #
  # @!macro group_configure

  # Make resource part of the group topic, it will overwrite existing membership array
  #
  # @param [String|Array] args name of group topic/topics
  def configure_membership(*args)
    new_membership = [args[0]].flatten

    new_membership.each do |new_m|
      unless @membership.include?(new_m)
        OmfCommon.comm.subscribe(new_m) do |t|
          if t.error?
            warn "Group #{new_m} disappeared"
            #EM.next_tick do
            #  @membership.delete(m)
            #end
          else
            self.synchronize do
              @membership << new_m
              @membership_topics[new_m] = t
              self.inform(:status, { membership: @membership }, t)
            end

            t.on_message(@uid) do |imsg|
              process_omf_message(imsg, t)
            end
          end
        end
      end
    end
    @membership
  end

  # @!endgroup

  # Parse omf message and execute as instructed by the message
  #
  # @param [OmfCommon::Message] message FRCP message
  # @param [OmfCommon::Comm::Topic] topic subscribed to
  def process_omf_message(message, topic)
    return unless check_guard(message)

    unless message.is_a? OmfCommon::Message
      raise ArgumentError, "Expected OmfCommon::Message, but got '#{message.class}'"
    end

    unless message.valid?
      raise StandardError, "Invalid message received: #{pubsub_item_payload}. Please check protocol schema of version #{OmfCommon::PROTOCOL_VERSION}."
    end

    objects_by_topic(topic.id.to_s).each do |obj|
      OmfRc::ResourceProxy::MPReceived.inject(Time.now.to_f, self.uid, 
        topic.id.to_s, message.mid) if OmfCommon::Measure.enabled?
      execute_omf_operation(message, obj, topic)
    end
  end

  # Execute operation based on the type of the message
  #
  # @param [OmfCommon::Message] message FRCP message
  # @param [OmfRc::ResourceProxy::AbstractResource] obj resource object
  # @param [OmfCommon::Comm::Topic] topic subscribed to
  def execute_omf_operation(message, obj, topic)
    begin
      response_h = handle_message(message, obj)
    rescue  => ex
      err_resp = message.create_inform_reply_message(nil, {}, src: resource_address)
      err_resp[:reason] = ex.to_s
      error "Encountered exception, returning ERROR message"
      debug ex.message
      debug ex.backtrace.join("\n")
      return inform(:error, err_resp, topic)
    end

    case message.operation
    #when :create
    #  inform(:creation_ok, response_h, topic)
    when :request, :configure
      inform(:status, response_h, topic)
    when :release
      OmfCommon.eventloop.after(RELEASE_WAIT) do
        inform(:released, response_h, topic) if response_h[:res_id]
      end
    end
  end

  # Handling all messages, then delegate them to individual handler
  #
  # @param [OmfCommon::Message] message FRCP message
  # @param [OmfRc::ResourceProxy::AbstractResource] obj resource object
  def handle_message(message, obj)
    response = message.create_inform_reply_message(nil, {}, src: resource_address)
    response.replyto replyto_address(obj, message.replyto)

    case message.operation
    when :create
      handle_create_message(message, obj, response)
    when :request
      handle_request_message(message, obj, response)
    when :configure
      handle_configure_message(message, obj, response)
    when :release
      handle_release_message(message, obj, response)
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

  # FRCP CREATE message handler
  #
  # @param [OmfCommon::Message] message FRCP message
  # @param [OmfRc::ResourceProxy::AbstractResource] obj resource object
  # @param [OmfCommon::Message] response initialised FRCP INFORM message object
  def handle_create_message(message, obj, response)
    new_name = message[:name] || message[:hrn]
    msg_props = message.properties.merge({ hrn: new_name })

    obj.create(message[:type], msg_props, &lambda do |new_obj|
      begin
        response[:res_id] = new_obj.resource_address
        response[:uid] = new_obj.uid

        # Getting property status, for preparing inform msg
        add_prop_status_to_response(new_obj, msg_props.keys, response)

				if (cred = new_obj.certificate)
          response[:cert] = cred.to_pem_compact
        end
        # self here is the parent
        self.inform(:creation_ok, response)
      rescue  => ex
        err_resp = message.create_inform_reply_message(nil, {}, src: resource_address)
        err_resp[:reason] = ex.to_s
        error "Encountered exception, returning ERROR message"
        debug ex.message
        debug ex.backtrace.join("\n")
        return self.inform(:error, err_resp)
      end
    end)
  end

  # FRCP CONFIGURE message handler
  #
  # @param [OmfCommon::Message] message FRCP message
  # @param [OmfRc::ResourceProxy::AbstractResource] obj resource object
  # @param [OmfCommon::Message] response initialised FRCP INFORM message object
  def handle_configure_message(message, obj, response)
    message.each_property do |key, value|
      method_name =  "#{message.operation.to_s}_#{key}"
      p_value = message[key]

      if namespaced_property?(key)
        response[key, namespace] = obj.__send__(method_name, p_value)
      else
        response[key] = obj.__send__(method_name, p_value)
      end
    end
  end

  # FRCP REQUEST message handler
  #
  # @param [OmfCommon::Message] message FRCP message
  # @param [OmfRc::ResourceProxy::AbstractResource] obj resource object
  # @param [OmfCommon::Message] response initialised FRCP INFORM message object
  def handle_request_message(message, obj, response)
    request_props = if message.has_properties?
                      message.properties.keys.map(&:to_sym) & obj.request_available_properties.request
                    else
                      # Return ALL props when nothing specified
                      obj.request_available_properties.request
                    end

    request_props.each do |p_name|
      method_name = "request_#{p_name.to_s}"
      value = obj.__send__(method_name)
      if value
        if namespaced_property?(p_name)
          response[p_name, namespace] = value
        else
          response[p_name] = value
        end
      end
    end
  end

  # FRCP RELEASE message handler
  #
  # @param [OmfCommon::Message] message FRCP message
  # @param [OmfRc::ResourceProxy::AbstractResource] obj resource object
  # @param [OmfCommon::Message] response initialised FRCP INFORM message object
  def handle_release_message(message, obj, response)
    res_id = message.res_id
    released_obj = obj.release(res_id)
    # TODO: Under what circumstances would 'realease_obj' be NIL
    #
    # When release message send to a group, for bulk releasing,
    # the proxy might not be aware of a res_id it received
    response[:res_id] = released_obj.resource_address if released_obj
    response
  end


  # Publish an inform message
  # @param [Symbol] itype the type of inform message
  # @param [Hash | Hashie::Mash | Exception | String] inform_data the type of inform message
  # @param [String] topic Name of topic to send it. :ALL means to uid as well s all members
  #
  def inform(itype, inform_data, topic = nil)
    inform_data = inform_data.dup # better make a copy
    unless address = resource_address
      OmfCommon.eventloop.after(1) do
        # try again in a bit and see if address has been set by then
        inform(itype, inform_data, topic = nil)
      end
      warn "INFORM message delayed as resource's address is not known yet"
      return
    end

    if inform_data.is_a? Hash
      inform_data = Hashie::Mash.new(inform_data) if inform_data.class == Hash
      #idata = inform_data.dup
      idata = {
        src: address,
        type: self.type  # NOTE: Should we add the object's type as well???
      }
      message = OmfCommon::Message.create_inform_message(itype.to_s.upcase, inform_data, idata)
    else
      message = inform_data
    end

    message.itype = itype
    unless itype == :released
      message[:hrn] ||= self.hrn if self.hrn
    end

    # Just send to all topics, including group membership
    (membership_topics.map { |mt| mt[1] } + @topics).each do |t| 
      t.publish(message) 
      OmfRc::ResourceProxy::MPPublished.inject(Time.now.to_f,
        self.uid, t.id, message.mid) if OmfCommon::Measure.enabled?
    end
  end

  def inform_status(props)
    inform :status, props
  end

  def inform_error(reason)
    error reason
    inform :error, { reason: reason }
  end

  def inform_creation_failed(reason)
    error reason
    inform :creation_failed, { reason: reason }
  end

  def inform_warn(reason)
    warn reason
    inform :warn, { reason: reason }
  end

  # Return a hash describing a reference to this object
  #
  # @return [Hash]
  def to_hash
    { uid: @uid, address: resource_address() }
  end

  private

  # To deal with FRCP messages published to a group topic, we need to find out what resources belongs to that topic.
  #
  # @param [String] name of the topic
  # @return [Array<OmfRc::ResourceProxy::AbstractResource>]
  def objects_by_topic(name)
    if name == uid || membership.any? { |m| m.include?(name) }
      objs = [self]
    else
      objs = children.find_all { |v| v.uid == name || v.membership.any? { |m| m.include?(name) } }
    end
    objs
  end

  # Retrieve replyto address
  #
  # @param [OmfRc::ResourceProxy::AbstractResource] obj resource object
  # @param [String] replyto address where reply should send to
  def replyto_address(obj, replyto = nil)
    replyto || obj.uid
  end

  # Checking if current object met the condition set by message guard section
  #
  # @param [OmfCommon::Message] message FRCP message
  # @return [Boolean]
  def check_guard(message)
    guard = message.guard

    if guard.nil? || guard.empty?
      return true
    else
      guard.keys.all? do |key|
        value = self.__send__("request_#{key}")
        if value.kind_of? Symbol
          value.to_s == guard[key].to_s
        else
          value == guard[key]
        end
      end
    end
  end

  # Used for setting properties came with FRCP CREATE message.
  #
  # @param [OmfRc::ResourceProxy::AbstractResource] res_ctx resource object it applies to
  # @param [Hash] props a set of key value pair of properties configuration
  def init_configure(res_ctx, props)
    props.each do |key, value|
      if res_ctx.respond_to? "configure_#{key}"
        res_ctx.__send__("configure_#{key}", value)
      elsif res_ctx.respond_to? "initialise_#{key}"
        # For read only props, they won't have "configure" method defined,
        # we can still set them directly during this creation.
        res_ctx.__send__("initialise_#{key}", value)
      end
    end

    call_hook(:after_initial_configured, res_ctx)
  end

  # Getting property status, adding them to inform message
  #
  # @param [OmfRc::ResourceProxy::AbstractResource] res_ctx resource object it applies to
  # @param [Array] msg_props a set of property names coming via configure/create message
  def add_prop_status_to_response(res_ctx, msg_props, response)
    msg_props.each do |p|
      # Property can either be defined as 'request' API call
      # or just an internal variable, e.g. uid, hrn, etc.
      if res_ctx.respond_to? "request_#{p}"
        response[p] = res_ctx.__send__("request_#{p}")
      elsif res_ctx.respond_to? p
        response[p] = res_ctx.__send__(p)
      end
    end
  end

  # Check if a property has namespace associated
  #
  # @param [String] name of the property
  def namespaced_property?(name)
    respond_to?(:namespace) && name =~ /^(.+)__(.+)$/
  end
end
