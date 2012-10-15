require 'xmlrpc/client'

module OmfRc::Util::OpenflowTools
  include OmfRc::ResourceProxyDSL

  # The version of the flowvisor that this resource is able to control
  FLOWVISOR_VERSION = "FV version=flowvisor-0.8.4"

  # Parts of the regular expression that describes a flow entry for flowvisor
  FLOWVISOR_FLOWENTRY_REGEXP_DEVIDED = [
    /dpid=\[(?<device>.+)\]/,
    /ruleMatch=\[OFMatch\[(?<match>.+)\]\]/,
    /actionsList=\[Slice:(?<slice>.+)=(?<actions>.+)\]/,
    /id=\[(?<id>.+)\]/,
    /priority=\[(?<priority>.+)\]/
  ]

  # The regular expression that describes a flow entry for flowvisor
  FLOWVISOR_FLOWENTRY_REGEXP = /FlowEntry\[#{FLOWVISOR_FLOWENTRY_REGEXP_DEVIDED.join(',')},\]/

  # The names of the flow (or flow entry) features
  FLOW_FEATURES = %w{device match slice actions id priority}

  # The names of the flow (or flow entry) features that are specified by the "match" feature
  FLOW_MATCH_FEATURES = %w{in_port eth_src eth_dst ip_src ip_dst}

  # The default features of a new flow (or flow entry)
  FLOW_DEFAULTS = {
    priority: "10",
    actions:  "4"
  }


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
    result.map! do |line|
      array_values = line.match(FLOWVISOR_FLOWENTRY_REGEXP)[1..-1]
        # Example of above array's content: %w{00:00:...:01 in_port=1 test 4 30 10}
      array_features_values_zipped = FLOW_FEATURES.zip(array_values)
        # Example of above array's content: %w{device 00:00:...:01 match in_port=1 slice test actions 4 id 30 priority 10}
      hash = Hashie::Mash.new(Hash[array_features_values_zipped])
      # The following code adds extra features that are specified by the "match" feature
      hash["match"].split(",").each do |couple|
        array = couple.split("=")
        hash[array[0]] = array[1]
      end
      hash
    end
    result.delete_if {|hash| hash["slice"] != resource.property.name} if resource.type.to_sym == :openflow_slice
    FLOW_FEATURES.each do |feature|
      result.delete_if {|hash| hash[feature] != filter[feature].to_s} if filter[feature]
    end if filter
    result
  end

  work :transformed_parameters do |resource, parameters|

    match = []
    FLOW_MATCH_FEATURES.each do |feature|
      match << "#{feature}=#{parameters[feature]}" if parameters[feature]
    end
    match = match.join(",")

    result = []
    case parameters.operation
    when "add"
      h = Hashie::Mash.new
      h.operation = parameters.operation.upcase
      h.priority  = parameters.priority ? parameters.priority.to_s : FLOW_DEFAULTS[:priority]
      h.dpid      = parameters.device.to_s
      h.actions   = "Slice:#{resource.property.name}=#{(parameters.actions ? parameters.actions : FLOW_DEFAULTS[:actions])}"
      h.match     = "OFMatch[#{match}]"
      result << h
    when "remove"
      resource.flows(parameters).each do |f|
        if f.match == match
          h = Hashie::Mash.new
          h.operation = parameters.operation.upcase
          h.id = f.id
          result << h
        end
      end
    end
    result
  end
end
