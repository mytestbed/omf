require 'xmlrpc/client'

module OmfRc::ResourceProxy::OpenflowSliceFactory
  include OmfRc::ResourceProxyDSL

  register_proxy :openflow_slice_factory

  module ConnectionDefaults
    DEFAULT_CONNECTION_HOST = "localhost"
    DEFAULT_CONNECTION_PATH = "/xmlrc"
    DEFAULT_CONNECTION_PORT = "8080"
    DEFAULT_CONNECTION_PROXY_HOST = nil
    DEFAULT_CONNECTION_PROXY_PORT = nil
    DEFAULT_CONNECTION_USER = "fvadmin"
    DEFAULT_CONNECTION_PASSWORD = "openflow"
    DEFAULT_CONNECTION_USE_SSL = "true"
    DEFAULT_CONNECTION_TIMEOUT = nil
  end
  include ConnectionDefaults

  module OpenflowKeys
    # Argument-names for the Flowvisor handler related with flowSpaces.
    OP_KEY = "operation"
    ID_KEY = "id"
    PRIORITY_KEY = "priority"
    DPID_KEY = "dpid"
    MATCH_KEY = "match"
    ACTIONS_KEY = "actions"
  end
  include OpenflowKeys


  hook :before_ready do |resource|
    # The arguments for the connection between this proxy and Flowvisor instance.
    resource.property.conn_args = {
      :host=>DEFAULT_CONNECTION_HOST,
      :path=>DEFAULT_CONNECTION_PATH,
      :port=>DEFAULT_CONNECTION_PORT,
      :proxy_host=>DEFAULT_CONNECTION_PROXY_HOST,
      :proxy_port=>DEFAULT_CONNECTION_PROXY_PORT,
      :user=>DEFAULT_CONNECTION_USER,
      :password=>DEFAULT_CONNECTION_PASSWORD,
      :use_ssl=>DEFAULT_CONNECTION_USE_SSL,
      :timeout=>DEFAULT_CONNECTION_TIMEOUT
    }
    # The connection between this proxy and Flowvisor instance.
    resource.property.conn = XMLRPC::Client.new_from_hash(resource.property.conn_args)
    resource.property.conn.instance_variable_get("@http").verify_mode = OpenSSL::SSL::VERIFY_NONE
  end


  request :connection do |resource|
    resource.property.conn_args
  end

  configure :connection do |resource, conn_args|
    resource.property.conn_args.update(conn_args)
    resource.property.conn = XMLRPC::Client.new_from_hash(resource.property.conn_args)
    resource.property.conn.instance_variable_get("@http").verify_mode = OpenSSL::SSL::VERIFY_NONE
    resource.property.conn_args
  end


  # Key is the request/configure name => value is the name of the related flowvisor handler.
  REQUESTS = { :slices => :listSlices, :devices => :listDevices, :deviceInfo => :getDeviceInfo, :deviceStats => :getSwitchStats }
  REQUESTS.each do |request_name, handler_name|
    request request_name do |resource, handler_args|
      resource.property.conn.call("api."+handler_name.to_s, *handler_args.values.map(&:to_s))
    end
  end

  request :flowSpaces do |resource|
     results = resource.property.conn.call("api.listFlowSpace")
     results.map do |line|
       array = line.split(/FlowEntry\[|=\[|\],\]?/).reject(&:empty?)
       Hash[*array].each_with_object({}) { |(k, v), h| h[(k.downcase[MATCH_KEY] ? MATCH_KEY : (k.downcase[ACTIONS_KEY] ? ACTIONS_KEY : k))] = v }
     end
  end
end
