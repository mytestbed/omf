# This resourse is related with a flowvisor instance and behaves as a proxy between experimenter and flowvisor.
#
module OmfRc::ResourceProxy::OpenflowSliceFactory
  include OmfRc::ResourceProxyDSL

  # The default arguments of the communication between this resource and the flowvisor instance
  FLOWVISOR_CONNECTION_DEFAULTS = {
    :host       => "localhost",
    :path       => "/xmlrc",
    :port       => "8080",
    :proxy_host => nil,
    :proxy_port => nil,
    :user       => "fvadmin",
    :password   => "openflow",
    :use_ssl    => "true",
    :timeout    => nil
  }


  register_proxy :openflow_slice_factory

  utility :openflow_tools


  # Checks if the created child is an :openflow_slice resource and passes the connection arguments that are essential for the connection with flowvisor instance
  hook :before_create do |resource, type, opts = nil|
    if type.to_sym != :openflow_slice
      raise "This resource doesn't create resources of type "+type
    end
    begin
      resource.flowvisor_connection
    rescue
      raise "This resource is not connected with a flowvisor instance, so it cannot create openflow slices"
    end
    opts.property ||= Hashie::Mash.new
    opts.property.flowvisor_connection_args = resource.property.flowvisor_connection_args
  end


  # A new resource uses the default connection arguments (ip adress, port, etc) to connect with a flowvisor instance
  hook :before_ready do |resource|
    resource.property.flowvisor_connection_args = FLOWVISOR_CONNECTION_DEFAULTS
  end


  # Configures the flowvisor connection arguments (ip adress, port, etc)
  configure :flowvisor_connection do |resource, flowvisor_connection_args|
    raise "Connection with a new flowvisor instance is not allowed if there exist created slices" if !resource.children.empty?
    resource.property.flowvisor_connection_args.update(flowvisor_connection_args)
  end


  # Returns the flowvisor connection arguments (ip adress, port, etc)
  request :flowvisor_connection do |resource|
    resource.property.flowvisor_connection_args
  end

  # Returns a list of the existed slices or the connected devices
  {:slices => "listSlices", :devices => "listDevices"}.each do |request_sym, handler_name|
    request request_sym do |resource|
      resource.flowvisor_connection.call("api.#{handler_name}")
    end
  end

  # Returns information or statistics for a device specified by the given id
  {:device_info => "getDeviceInfo", :device_stats => "getSwitchStats"}.each do |request_sym, handler_name|
    request request_sym do |resource, device|
      resource.flowvisor_connection.call("api.#{handler_name}", device.to_s)
    end
  end
end
