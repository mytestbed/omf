require 'xmlrpc/client'

# This resourse is related with a flowvisor instance and behaves as a proxy between experimenter and flowvisor.
#
module OmfRc::ResourceProxy::OpenflowSliceFactory
  include OmfRc::ResourceProxyDSL

  # The version of the flowvisor that this resource is able to control 
  FLOWVISOR_VERSION = "FV version=flowvisor-0.8.4"
  
  # The default features of the communication between this resource and the flowvisor instance
  FLOWVISOR_DEFAULTS = {
    :host=>"localhost",
    :path=>"/xmlrc",
    :port=>"8080",
    :proxy_host=>nil,
    :proxy_port=>nil,
    :user=>"fvadmin",
    :password=>"openflow",
    :use_ssl=>"true",
    :timeout=>nil
  }

  register_proxy :openflow_slice_factory

  # Checks if the created child is an "Openflow Slice" and passes the resource property "fv", that is essential for the communication with flowvisor
  def create(type, opts = nil)
    if type.to_sym != :openflow_slice
      raise "This resource doesn't create resources of type "+type
    elsif !self.property.fv
      raise "This resource is not connected with a flowvisor instance and cannot create slices"
    end 
    opts.property ||= Hashie::Mash.new
    opts.property.fv = self.property.fv
    super
  end

  # By default the new resource searchs for a flowvisor instance using the default features (ip adress, port, etc)
  hook :before_ready do |resource|
    resource.property.fv_args = FLOWVISOR_DEFAULTS
    resource.config_fv
  end

  # Configures the flowvisor communication features (ip adress, port, etc)
  configure :flowvisor do |resource, fv_args|
    raise "Connection with a new flowvisor instance is not allowed if there are created slices" if !resource.children.empty?
    resource.property.fv_args.update(fv_args)
    resource.config_fv
    resource.property.fv_args
  end

  # Returns the flowvisor communication features (ip adress, port, etc)
  request :flowvisor do |resource|
    resource.property.fv_args
  end

  # Returns a list of existed slices or connected devices
  { :slices => "listSlices", :devices => "listDevices" }.each do |request_sym, handler_name|
    request request_sym do |resource|
      raise "There is no connection with a flowvisor instance" if !resource.property.fv 
      resource.property.fv.call("api."+handler_name)
    end
  end

  # Returns information or statistics for a specific device, which is related with flowvisor
  { :deviceInfo => "getDeviceInfo", :deviceStats => "getSwitchStats" }.each do |request_sym, handler_name|
    request request_sym do |resource, device|
      raise "There is no connection with a flowvisor instance" if !resource.property.fv 
      resource.property.fv.call("api."+handler_name, device.to_s)
    end
  end

  # Returns the flows (flow entries) that exist for this flowvisor
  request :flows do |resource|
    raise "There is no connection with a flowvisor instance" if !resource.property.fv 
    result = resource.property.fv.call("api.listFlowSpace")
    result.map do |line|
      array = line.split(/FlowEntry\[|=\[|\],\]?/).reject(&:empty?)
      Hash[*array]
    end
  end

  # Internal function that creates and checks communication with a new flowvisor instance
  work :config_fv do |resource|
    begin
      fv = XMLRPC::Client.new_from_hash(resource.property.fv_args)
      fv.instance_variable_get("@http").verify_mode = OpenSSL::SSL::VERIFY_NONE
      ping_msg = "ping"
      resource.property.fv = ( fv.call("api.ping", ping_msg) == ("PONG("+resource.property.fv_args[:user]+"): "+FLOWVISOR_VERSION+"::"+ping_msg) ) ? fv : nil
    rescue
      resource.property.fv = nil
    ensure
      if !resource.property.fv
        fv_args_str = resource.property.fv_args.map{|k,v| "#{k}=\"#{v}\""}.join(' ')
        raise "Connection with flowvisor ["+fv_args_str+"] was not successful"
      end
    end
  end
end
