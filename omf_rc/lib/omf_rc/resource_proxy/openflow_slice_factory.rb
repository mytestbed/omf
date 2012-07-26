require 'xmlrpc/client'

module OmfRc::ResourceProxy::Openflowslicefactory
  include OmfRc::ResourceProxyDSL

  register_proxy :openflowslicefactory

  module OpenflowSpaceKeys
    # Argument-names for the Flowvisor handler related with flowSpaces.
    OP_KEY = "operation"
    ID_KEY = "id"
    PRIORITY_KEY = "priority"
    DPID_KEY = "dpid"
    MATCH_KEY = "match"
    ACTIONS_KEY = "actions"
  end
  include OpenflowSpaceKeys


  hook :before_ready do |resource|
    resource.property.conn_args = {
      :host=>"localhost",
      :path=>"/xmlrc",
      :port=>"8080",
      :proxy_host=>nil,
      :proxy_port=>nil,
      :user=>"fvadmin",
      :password=>"openflow",
      :use_ssl=>true,
      :timeout=>nil
    }
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

  #:slice => :createSlice
  #:deleteSlice, :getSliceInfo, :getSliceStats, :changePasswd, :changeSlice, :createSlice
  #:addFlowSpace, :removeFlowSpace , :changeFlowSpace

  #FUNCTIONS_FLOWSPACE.each do |function|
  #  request function do |resource, function_args|
  #    str = function.to_s
  #    str.slice!("FlowSpace")
  #    function_args[OP_KEY] = str.upcase
  #    resource.property.conn.call("api.changeFlowSpace", [function_args.each_with_object({}) { |(k, v), h| h[k] = v.to_s }])
  #  end
  #end
end
