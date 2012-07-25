require 'xmlrpc/client'

module OmfRc::ResourceProxy::Flowvisor
  include OmfRc::ResourceProxyDSL

  register_proxy :flowvisor


  # All supported functions categorized depending on the number of their arguments (except of "FlowSpace" functions).
  FUNCTIONS = [
    [:listSlices, :listDevices],
    [:deleteSlice, :getSliceInfo, :getSliceStats, :getSwitchStats, :getSwitchFlowDB, :getDeviceInfo],
    [:changePasswd, :getSliceRewriteDB],
    [:changeSlice],
    [:createSlice]
  ]
  # The FlowSpace functions (except of listFlowSpace function).
  FUNCTIONS_FLOWSPACE = [:addFlowSpace, :removeFlowSpace , :changeFlowSpace]
  # Constants usefull for functions that manipulate flowspaces.
  OP_KEY = "operation"
  ID_KEY = "id"
  PRIORITY_KEY = "priority"
  DPID_KEY = "dpid"
  MATCH_KEY = "match"
  ACTIONS_KEY = "actions"


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


  request :get_connection_params do |resource|
    resource.property.conn_args
  end

  configure :connection do |resource, conn_args|
    resource.property.conn_args.update(conn_args)
    resource.property.conn = XMLRPC::Client.new_from_hash(resource.property.conn_args)
    resource.property.conn.instance_variable_get("@http").verify_mode = OpenSSL::SSL::VERIFY_NONE
  end


  FUNCTIONS.each do |function_category|
    function_category.each do |function|
      request function do |resource, function_args|
        resource.property.conn.call("api."+function.to_s, *function_args.values.map(&:to_s))
      end
    end
  end

  FUNCTIONS_FLOWSPACE.each do |function|
    request function do |resource, function_args|
      str = function.to_s
      str.slice!("FlowSpace")
      function_args[OP_KEY] = str.upcase
      resource.property.conn.call("api.changeFlowSpace", [function_args.each_with_object({}) { |(k, v), h| h[k] = v.to_s }])
    end
  end

  request :listFlowSpace do |resource|
     results = resource.property.conn.call("api.listFlowSpace")
     results.map do |line|
       array = line.split(/FlowEntry\[|=\[|\],\]?/).reject(&:empty?)
       Hash[*array].each_with_object({}) { |(k, v), h| h[(k.downcase[MATCH_KEY] ? MATCH_KEY : (k.downcase[ACTIONS_KEY] ? ACTIONS_KEY : k))] = v }
     end
  end
end
