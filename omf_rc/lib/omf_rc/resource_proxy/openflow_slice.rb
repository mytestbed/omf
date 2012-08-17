# This resource is created from the parent :openflow_slice_factory resource.
# It is related with a slice of a flowvisor instance, and behaves as a proxy between experimenter and the actual flowvisor slice.
#
module OmfRc::ResourceProxy::OpenflowSlice
  include OmfRc::ResourceProxyDSL

  # The default parameters of a new slice. The openflow controller is assumed to be in the same working station with flowvisor instance
  SLICE_DEFAULTS = {
    :passwd => "1234",
    :url    => "tcp:127.0.0.1:9933",
    :email  => "nothing@nowhere"
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

  # Adds/removes a flow to this slice, specified by a device and a port [and a dest ip address optionally]
  configure :flows do |resource, config_desc|
    resource.flowvisor_connection.call("api.changeFlowSpace", resource.call_parameters(config_desc))
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
