#require 'omf_rc/deferred_process'
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

class OmfRc::ResourceProxy::AbstractResource
  include MonitorMixin

  # Time to wait before shutting down event loop, wait for deleting pubsub topics
  DISCONNECT_WAIT = 5
  # Time to wait before releasing resource, wait for deleting pubsub topics
  RELEASE_WAIT = 5

  DEFAULT_CREATION_OPTS = {
    suppress_create_message: false,
    create_children_resources: true
  }

  # @!attribute property
  #   @return [String] the resource's internal meta data storage
  attr_accessor :uid, :hrn, :type, :comm, :property, :certificate
  attr_reader :opts, :children, :membership, :creation_opts, :membership_topics

  # Initialisation
  #
  # @param [Symbol] type resource proxy type
  #
  # @param [Hash] opts options to be initialised
  # @option opts [String] :uid Unique identifier
  # @option opts [String] :hrn Human readable name
  # @option opts [Hash] :property A hash for keeping internal state
  # @option opts [Hash] :instrument A hash for keeping instrumentation-related state
  # @option opts [OmfCommon::Auth::Certificate] :certificate The certificate for this resource
  #
  # @param [Hash] creation_opts options to control the resource creation process
  # @option creation_opts [Boolean] :suppress_create_message Don't send an initial CREATION.OK Inform message
  # @option creation_opts [Boolean] :create_children_resources Immediately create 'known' children resources, such as interfaces on nodes
  #
  def initialize(type, opts = {}, creation_opts = {}, &creation_callback)
    @opts = Hashie::Mash.new(opts)
    @creation_opts = Hashie::Mash.new(DEFAULT_CREATION_OPTS.merge(creation_opts))

    @type = type
    @uid = (@opts.uid || SecureRandom.uuid).to_s
    @hrn = @opts.hrn && @opts.hrn.to_s

    @children ||= []
    @membership ||= []
    @topics = []
    @membership_topics ||= {}

    @property = @opts.property || Hashie::Mash.new
    @property.merge!(@opts.except([:uid, :hrn, :property, :instrument]))

    OmfCommon.comm.subscribe(@uid) do |t|
      @topics << t

      if t.error?
        warn "Could not create topic '#{uid}', will shutdown, trying to clean up old topics. Please start it again once it has been shutdown."
        OmfCommon.comm.disconnect()
      else
        if @certificate = @opts.certificate
          OmfCommon::Auth::CertificateStore.instance.register(@certificate, t.address)
        else
          if pcert = @opts.parent_certificate
            @certificate = pcert.create_for(@uid, @type, t.address)
          end
        end

        creation_callback.call(self) if creation_callback
        copts = { res_id: self.resource_address, src: self.resource_address}
        copts[:cert] = @certificate.to_pem_compact if @certificate
        t.inform(:creation_ok, @property, copts)

        t.on_message(nil, @uid) do |imsg|
          process_omf_message(imsg, t)
        end
      end
    end

    super()
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

  # Overwirte methods to add ghost methods
  def methods
    super + property.keys.map { |v| ["configure_#{v}".to_sym, "request_#{v}".to_sym] }.flatten
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
    OmfCommon.comm.disconnect
  end

  # Create a new resource in the context of this resource. This resource becomes parent, and newly created resource becomes child
  #
  # @param (see #initialize)
  def create(type, opts = {}, creation_opts = {}, &creation_callback)
    unless request_supported_children_type.include?(type)
      raise StandardError, "Resource #{type} is not designed to be created by #{self.type}"
    end

    opts[:parent_certificate] = @certificate
    before_create(type, opts) if respond_to? :before_create
    new_resource = OmfRc::ResourceFactory.create(type.to_sym, opts, creation_opts, &creation_callback)
    after_create(new_resource) if respond_to? :after_create

    self.synchronize do
      children << new_resource
    end
    new_resource
  end

  # Release a child resource
  #
  # @return [AbstractResource] Relsead child or nil if error
  #
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
  # Return true if successful
  #
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
    self.before_release if self.respond_to? :before_release
    props = {
      res_id: resource_address
    }
    props[:hrn] = hrn if hrn
    inform :released, props

    # clean up topics
    @topics.each do |t|
      t.unsubscribe
    end

    @membership_topics.each_value do |t|
      if t.respond_to? :delete_on_message_cbk_by_id
        t.delete_on_message_cbk_by_id(@uid)
      end
      t.unsubscribe
    end

    true
  end

  # Return a list of all loaded resource proxies
  #
  def request_proxies(*args)
    OmfRc::ResourceFactory.proxy_list
  end

  def request_supported_children_type(*args)
    OmfRc::ResourceFactory.proxy_list.reject { |v| v == @type.to_s }.find_all do |k, v|
      (v.create_by && v.create_by.include?(@type.to_sym)) || v.create_by.nil?
    end.map(&:first)
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
    self.synchronize do
      @hrn = hrn
    end
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

            t.on_message(nil, @uid) do |imsg|
              process_omf_message(imsg, t)
            end
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
    return unless check_guard(message)

    unless message.is_a? OmfCommon::Message
      raise ArgumentError, "Expected OmfCommon::Message, but got '#{message.class}'"
    end

    unless message.valid?
      raise StandardError, "Invalid message received: #{pubsub_item_payload}. Please check protocol schema of version #{OmfCommon::PROTOCOL_VERSION}."
    end

    objects_by_topic(topic.id.to_s).each do |obj|
      if OmfCommon::Measure.enabled?
        OmfRc::ResourceProxy::MPReceived.inject(Time.now.to_f, self.uid, topic, message.mid)
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
  def handle_message(message, obj)
    response = message.create_inform_reply_message(nil, {}, src: resource_address)
    response.replyto replyto_address(obj, message.replyto)

    case message.operation
    when :create
      handle_create_message(message, obj, response)
    when :request
      response = handle_request_message(message, obj, response)
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

  def handle_create_message(message, obj, response)
    new_name = message[:name] || message[:hrn]
    mprops = message.properties.merge({ hrn: new_name })
    exclude = [:type, :hrn, :name, :uid]
    props = {}
    copts = {}
    mprops.each do |k, v|
      if exclude.include?(k)
        copts[k] = v
      else
        props[k] = v
      end
    end
    new_obj = obj.create(message[:type], copts) do |new_obj|
      begin
        response[:res_id] = new_obj.resource_address


        props.each do |key, value|
          method_name = "configure_#{key}"
          response[key] = new_obj.__send__(method_name, value)
        end
        response[:hrn] = new_obj.hrn
        response[:uid] = new_obj.uid
        response[:type] = new_obj.type
				if cred = new_obj.certificate
          response[:cert] = cred.to_pem_compact
        end

        new_obj.after_initial_configured if new_obj.respond_to? :after_initial_configured

        # self here is the parent
        self.inform(:creation_ok, response)
      rescue Exception => ex
        err_resp = message.create_inform_reply_message()
        err_resp[:reason] = ex.to_s
        error "Encountered exception, returning ERROR message"
        debug ex.message
        debug ex.backtrace.join("\n")
        return self.inform(:error, err_resp)
      end
    end
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
      #puts "NAME>> #{name.inspect}"

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
    if topic == :ALL
      inform(itype, inform_data)
      membership_topics.each {|m| inform(itype, inform_data, m[1])}
      return
    end

    topic ||= @topics.first
    if inform_data.is_a? Hash
      inform_data = Hashie::Mash.new(inform_data) if inform_data.class == Hash
      #idata = inform_data.dup
      idata = {
        src: @topics.first.address,
        type: self.type  # NOTE: Should we add the object's type as well???
      }
      message = OmfCommon::Message.create_inform_message(itype.to_s.upcase, inform_data, idata)
    else
      message = inform_data
    end

    message.itype = itype
    unless itype == :released
      #message[:uid] ||= self.uid
      #message[:type] ||= self.type
      message[:hrn] ||= self.hrn if self.hrn
    end

    topic.publish(message)

    OmfRc::ResourceProxy::MPPublished.inject(Time.now.to_f,
      self.uid, replyto, inform_message.mid) if OmfCommon::Measure.enabled?
  end

  def inform_status(props)
    inform :status, props
  end

  def inform_error(reason)
    error reason
    inform :error, {reason: reason}
  end

  def inform_warn(reason)
    warn reason
    inform :warn, {reason: reason}
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

  def replyto_address(obj, replyto = nil)
    replyto || obj.uid
  end

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
end
