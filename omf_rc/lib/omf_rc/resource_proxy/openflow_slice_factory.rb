require 'xmlrpc/client'

# This resourse is related with a Flowvisor instance and behaves as a proxy between experimenter and Flowvisor.
#
module OmfRc::ResourceProxy::OpenflowSliceFactory
  include OmfRc::ResourceProxyDSL

  # The version of the Flowvisor that this resource is able to control 
  FLOWVISOR_VERSION = "FV version=flowvisor-0.8.4"
  
  # The default features of the communication between this resource and the Flowvisor instance
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

  # Checks if the created child is an "Openflow Slice" and passes the resource property "fv", that is essential for the communication with Flowvisor
  def create(type, opts = nil)
    if type.to_sym != :openflow_slice
      raise "This resource doesn't create resources of type "+type
    elsif !self.property.fv
      raise "This resource is not connected with a Flowvisor instance and cannot create slices"
    end 
    opts.property ||= Hashie::Mash.new
    opts.property.fv = self.property.fv
    super
  end

  register_proxy :openflow_slice_factory

  # By default the new resource searchs for a Flowvisor instance using the default features (ip adress, port, etc)
  hook :before_ready do |resource|
    resource.property.fv_args = FLOWVISOR_DEFAULTS
    resource.config_fv
  end

  # Returns the Flowvisor communication features (ip adress, port, etc)
  request :flowvisor do |resource|
    resource.property.fv_args
  end

  # Configures the Flowvisor communication features (ip adress, port, etc)
  configure :flowvisor do |resource, fv_args|
    raise "Connection with a new Flowvisor instance is not allowed if there are created slices" if !resource.children.empty?
    resource.property.fv_args.update(fv_args)
    resource.config_fv
    resource.property.fv_args
  end

  # Returns the slices, devices or information for a specific device, that are related with Flowvisor
  { :slices => "listSlices", :devices => "listDevices", :deviceInfo => "getDeviceInfo", :deviceStats => "getSwitchStats" }.each do |request_sym, handler_name|
    request request_sym do |resource, handler_args|
      raise "There is no connection with a Flowvisor instance" if !resource.property.fv 
      begin
        resource.property.fv.call("api."+handler_name, *handler_args.values.map(&:to_s))
      rescue Exception
        raise "Flowvisor instance does not respond normally"
      end
    end
  end

  # Returns the flow spaces, that are created in Flowvisor
  request :flowSpaces do |resource|
    raise "There is no connection with a Flowvisor instance" if !resource.property.fv 
    begin
      result = resource.property.fv.call("api.listFlowSpace")
      result.map do |line|
        array = line.split(/FlowEntry\[|=\[|\],\]?/).reject(&:empty?)
        Hash[*array]
      end
    rescue Exception
      raise "Flowvisor instance does not respond normally"
    end
  end

  # Internal function that creates and checks communication with a new Flowvisor instance
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
        raise "Connection with Flowvisor ["+fv_args_str+"] was not successful"
      end
    end
  end
end
