require 'xmlrpc/client'

module OmfRc::Util::OpenflowTools
  include OmfRc::ResourceProxyDSL

  # The version of the flowvisor that this resource is able to control 
  FLOWVISOR_VERSION = "FV version=flowvisor-0.8.4"
  # Parts of the regular expression that describes a flow entry for flowvisor
  FLOWVISOR_FLOWENTRY_DEVIDED = [
    /dpid=\[(?<device>.+)\]/,
    /ruleMatch=\[OFMatch\[(?<match>.+)\]\]/,
    /actionsList=\[Slice:(?<slice>.+)=(?<actions>.+)\]/,
    /id=\[(?<id>.+)\]/,
    /priority=\[(?<priority>.+)\]/
  ]
  # The regular expression that describes a flow entry for flowvisor
  FLOWVISOR_FLOWENTRY = /FlowEntry\[#{FLOWVISOR_FLOWENTRY_DEVIDED.join(',')},\]/
  # The names of the flow (or flow entry) features 
  FLOW_FEATURES = %w{device match slice actions id priority}
  # The default parameters of a new flow (or flow entry)
  FLOW_DEFAULTS = Hashie::Mash.new({
    :priority => "10",
    :actions  => "4"
  })


  # Returns the flows (flow entries) that exist for this flowvisor
  request :flows do |resource, filter = nil|
    resource.flows(filter)
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
  work :flows do |resource, filter = nil|
    result = resource.flowvisor_connection.call("api.listFlowSpace")
    result.map! {|line| Hashie::Mash[Hash[FLOW_FEATURES.zip line.match(FLOWVISOR_FLOWENTRY)[1..-1]]]}
    result.delete_if {|hash| !hash["slice"] == resource.property.name} if resource.type.to_sym == :openflow_slice
    if filter
      result.delete_if do |hash|
        valid = true
        FLOW_FEATURES.each {|f| valid &= (hash[f] == filter[f].to_s) if filter[f]}
        !valid
      end
    else 
      result
    end
  end

  work :call_parameters do |resource, config_desc|
    result = []
    match  = "in_port=#{config_desc.port}"
    match += ",ip_dst=#{config_desc.ip_dst}" if config_desc.ip_dst
    case config_desc.operation
    when "add"
      h = Hashie::Mash.new
      h.operation = config_desc.operation.upcase
      h.priority  = config_desc.priority ? config_desc.priority.to_s : FLOW_DEFAULTS.priority
      h.dpid      = config_desc.device.to_s
      h.actions   = "Slice:#{resource.property.name}=#{(config_desc.actions ? config_desc.actions : FLOW_DEFAULTS.actions)}"
      h.match     = "OFMatch[#{match}]"
      result << h
    when "remove"
      resource.flows(config_desc).each do |f|
        h = Hashie::Mash.new
        h.operation = "REMOVE"
        h.id = f.id
        result << h
      end    
    end
    result
  end
end
