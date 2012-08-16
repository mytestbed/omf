# This resource is created from the parent :openflow_slice_factory resource.
# It is related with a slice of a flowvisor instance, and behaves as a proxy between experimenter and the actual flowvisor slice.
#
module OmfRc::ResourceProxy::OpenflowSlice
  include OmfRc::ResourceProxyDSL

  # The default parameters of a new slice. The openflow controller is assumed to be in the same working station with flowvisor instance
  SLICE_DEFAULTS = {
    :passwd=>"1234",
    :url=>"tcp:127.0.0.1:9933",
    :email=>"nothing@nowhere"
  }
  # The default parameters of a new flow (it is also named flow entry in flowvisor terminology)
  FLOW_DEFAULTS = {
    :priority=>"10",
    :actions=>"4"
  }


  register_proxy :openflow_slice

  utility :openflow_tools


  # Slice's name is initiated with value "nil"
  hook :before_ready do |resource|
    resource.property.name = nil
  end

  # Before release, the related flowvisor instance should also remove the corresponding slice
  hook :before_release do |resource|
    resource.flowvisor_connection.call("api.deleteSlice", resource.property.name)
  end


  # The name is one-time configured
  configure :name do |resource, name|
    raise "The name cannot be changed" if resource.property.name
    resource.property.name = name.to_s
    begin
      resource.flowvisor_connection.call("api.createSlice", name.to_s, *SLICE_DEFAULTS.values)
    rescue Exception => e
      if e.message["Cannot create slice with existing name"]
        logger.warn message = "The requested slice already existed in Flowvisor"
        message
      else
        raise e
      end
    end
  end

  # Configures the slice password
  configure :passwd do |resource, passwd|
    resource.flowvisor_connection.call("api.changePasswd", resource.property.name, passwd.to_s)
  end

  # Configures the slice parameters
  [:contact_email, :drop_policy, :controller_hostname, :controller_port].each do |configure_sym|
    configure configure_sym do |resource, value|
      resource.flowvisor_connection.call("api.changeSlice", resource.property.name, configure_sym.to_s, value.to_s)
    end
  end

  # Configures the flows of this slice (deprecated because it should be restricted)
  #[:addFlowSpace, :removeFlowSpace , :changeFlowSpace].each do |configure_sym|
  #  configure configure_sym do |resource, handler_args|
  #    str = configure_sym.to_s
  #    str.slice!("FlowSpace")
  #    handler_args["operation"] = str.upcase
  #    resource.property.fv.call("api.changeFlowSpace", [handler_args.each_with_object({}) {|(k, v), h| h[k] = v.to_s}])
  #  end
  #end

  # Adds/removes a flow to this slice, specified by a device and a port [and a dest ip address optionally]
  configure :flows do |resource, args|
    match =  "in_port=#{args.port}"
    match += ",ip_dst=#{args.ip_dst}" if args.ip_dst
    case args.action
    when "add"
      call_args = {
        "operation"=> "ADD", 
        "priority" => FLOW_DEFAULTS[:priority], 
        "dpid"     => args.device.to_s, 
        "actions"  => "Slice:#{resource.property.name}=#{FLOW_DEFAULTS[:actions]}", 
        "match"    => "OFMatch[#{match}]"
      }
      result = resource.flowvisor_connection.call("api.changeFlowSpace", [call_args])
    when "remove"
      resource.flows.each do |h|
        flow_is_found  = (h["device"] == args.device.to_s)
        flow_is_found &= (h["match"]  == "OFMatch[#{match}]")
        if flow_is_found
          call_args = {
            "operation"=> "REMOVE", 
            "id"       => h["id"]
          }
          resource.flowvisor_connection.call("api.changeFlowSpace", [call_args])
        end
      end    
    end
    resource.flows
  end


  # Returns a hash table with the name of this slice, its controller (ip and port) and other related information
  request :info do |resource|
    result = resource.flowvisor_connection.call("api.getSliceInfo", resource.property.name)
    result[:name] = resource.property.name
    result
  end

  # Returns a string with statistics about the use of this slice
  request :stats do |resource|
    resource.flowvisor_connection.call("api.getSliceStats", resource.property.name)
  end
end
