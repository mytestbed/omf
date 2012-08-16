require 'xmlrpc/client'

module OmfRc::Util::OpenflowTools
  include OmfRc::ResourceProxyDSL

  # The version of the flowvisor that this resource is able to control 
  FLOWVISOR_VERSION = "FV version=flowvisor-0.8.4"
  # The names of the flow features 
  FLOW_FEATURES = %w{device match slice id priority}


  # Returns the flows (flow entries) that exist for this flowvisor
  request :flows do |resource|
    resource.flows
  end


  # Internal function that creates a connection with a flowvisor instance and checks it
  work :flowvisor_connection do |resource|
    xmlrpc_client = XMLRPC::Client.new_from_hash(resource.property.flowvisor_connection_args)
    xmlrpc_client.instance_variable_get("@http").verify_mode = OpenSSL::SSL::VERIFY_NONE
    ping_msg = "test"
    pong_msg = "PONG(#{resource.property.flowvisor_connection_args[:user]}): #{FLOWVISOR_VERSION}::#{ping_msg}"
    raise "Connection with #{FLOWVISOR_VERSION} was not successful" if xmlrpc_client.call("api.ping", ping_msg) != pong_msg
    xmlrpc_client
  end

  # Internal function that returns the flows (flow entries) that exist in the connected flowvisor instance
  work :flows do |resource, id_set=nil|
    result = resource.flowvisor_connection.call("api.listFlowSpace")
    result.map! do |line|
      array = line.split(/FlowEntry\[|=\[|\],\]?/).reject(&:empty?)
      FLOW_FEATURES.each_with_index {|v,i| array[2*i] = v}
      Hash[*array]
    end
    if resource.type == "openflow_slice"
      result.delete_if {|hash| !hash["slice"][resource.property.name]}
    end
    if id_set
      result.select {|hash| id_set.include?hash["id"]}
    else
      result
    end
  end
end
