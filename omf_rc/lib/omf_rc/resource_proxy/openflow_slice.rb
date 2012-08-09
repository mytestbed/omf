require 'xmlrpc/client'
require 'omf_common'

# The "Openflow Slice" resource is created from the parent "Openflow Slice Factory" resource.
# It is related with a slice of a flowvisor instance, and behaves as a proxy between experimenter and the actual flowvisor slice.
# So, the whole state of the slice is keeped in the flowvisor instance.
# The communication with flowvisor is established from the parent resource, and it is included in the resource property "fv".
#
module OmfRc::ResourceProxy::OpenflowSlice
  include OmfRc::ResourceProxyDSL
  
  # The default parameters of a new slice. The openflow controller is assumed to be in the same working station with flowvisor instance
  SLICE_DEFAULTS = {
    :passwd=>"1234",
    :url=>"tcp:127.0.0.1",
    :email=>"nobody@nowhere"
  }

  # The default parameters of a new flow (it is also named flow space of flow entry in flowvisor terminology)
  FLOW_DEFAULTS = {
    :priority=>"10",
    :actions=>"4"
  }

  register_proxy :openflow_slice

  # Slice's name is initiated with value "nil"
  hook :before_ready do |resource|
    resource.property.name = nil
  end

  # Before release the related flowvisor instance should also be update to remove the corresponding slice
  hook :before_release do |resource|
    resource.property.fv.call("api.deleteSlice", resource.property.name)
  end

  # The name is allowed to be one-time configured. Once it is configured, a new slice is created in flowvisor instance
  configure :name do |resource, name|
    raise "The name of this slice has already been configured" if resource.property.name
    resource.property.name = name.to_s
    resource.property.fv.call("api.createSlice", name, *SLICE_DEFAULTS.values)
  end

  # Configures the slice password
  configure :passwd do |resource, passwd|
    resource.property.fv.call("api.changePasswd", resource.property.name, passwd.to_s)
  end

  # Configures the slice parameters
  [ :contact_email, :drop_policy, :controller_hostname, :controller_port ].each do |configure_sym|
    configure configure_sym do |resource, value|
      resource.property.fv.call("api.changeSlice"+handler_name, resource.property.name, configure_sym.to_s, value.to_s)
    end
  end

  # Configures the flows of this slice (deprecated because it should be restricted)
  #[ :addFlowSpace, :removeFlowSpace , :changeFlowSpace ].each do |configure_sym|
  #  configure configure_sym do |resource, handler_args|
  #    str = configure_sym.to_s
  #    str.slice!("FlowSpace")
  #    handler_args["operation"] = str.upcase
  #    resource.property.fv.call("api.changeFlowSpace", [handler_args.each_with_object({}) { |(k, v), h| h[k] = v.to_s }])
  #  end
  #end

  # Adds a flow to this slice, specified from a device and a port
  configure :addFlow do |resource, args|
    result = resource.property.fv.call( "api.changeFlowSpace", [{ "operation"=>"ADD", "priority"=>resource.priority(FLOW_DEFAULTS[:priority]), "dpid"=>resource.dpid(args.device), "actions"=>resource.actions(FLOW_DEFAULTS[:actions]), "match"=>resource.match(args.port) }] )
    resource.flow(result)
  end

  # Removes a flow from this slice, specified from a device and a port
  configure :deleteFlow do |resource, args|
    resource.flows.each do |h|
      if ( h["dpid"]==resource.dpid(args.device) && h["ruleMatch"]==resource.match(args.port) )
        resource.property.fv.call( "api.changeFlowSpace", [{ "operation"=>"REMOVE", "id"=> h["id"]}] )
      end
    end
  end

  # Returns the flows (flow spaces or flow entries) that exist for this flowvisor and are related with this slice
  request :flows do |resource|
    resource.flows
  end

  # Returns a hash table with the name of this slice, its controller (ip and port) and other related information
  request :info do |resource|
    result = resource.property.fv.call("api.getSliceInfo", resource.property.name)
    logger.info result
    result[:name] = resource.property.name
    result
  end

  # Returns a string with statistics about the use of this slice
  request :stats do |resource|
    resource.property.fv.call("api.getSliceStats", resource.property.name)
  end

  # Internal function that returns the flows (flow spaces or flow entries) that exist for this flowvisor and are related with this slice
  work :flows do |resource|
    result = resource.property.fv.call("api.listFlowSpace")
    result.map! do |line|
      array = line.split(/FlowEntry\[|=\[|\],\]?/).reject(&:empty?)
      Hash[*array]
    end
    result.delete_if {|h| !h["actionsList"][resource.property.name] }
  end
  # Returns a flow with the given id
  work :flow do |resource, id|
    resource.flows.select {|h| id.include?h["id"]}
  end
  # The wrappers that convert the given arguments (device, port, etc) to appropriately formated arguments for flowvisor
  work :priority do |resource, value| value.to_s end
  work :dpid do |resource, value| value end
  work :actions do |resource, value| "Slice:"+resource.property.name+"="+value.to_s end
  work :match do |resource, value| "OFMatch[in_port="+value.to_s+"]" end
end
