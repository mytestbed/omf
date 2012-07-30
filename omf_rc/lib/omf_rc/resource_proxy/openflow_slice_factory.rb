require 'xmlrpc/client'

module OmfRc::ResourceProxy::OpenflowSliceFactory
  include OmfRc::ResourceProxyDSL

  register_proxy :openflow_slice_factory


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


  hook :before_ready do |resource|
    resource.property.fv_args = FLOWVISOR_DEFAULTS
    resource.property.fv = XMLRPC::Client.new_from_hash(resource.property.fv_args)
    resource.property.fv.instance_variable_get("@http").verify_mode = OpenSSL::SSL::VERIFY_NONE
  end


  request :flowvisor do |resource|
    resource.property.fv_args
  end

  configure :flowvisor do |resource, fv_args|
    resource.property.fv_args.update(fv_args)
    resource.property.fv = XMLRPC::Client.new_from_hash(resource.property.fv_args)
    resource.property.fv.instance_variable_get("@http").verify_mode = OpenSSL::SSL::VERIFY_NONE
    resource.property.fv_args
  end


  { :slices => "listSlices", :devices => "listDevices", :deviceInfo => "getDeviceInfo", :deviceStats => "getSwitchStats" }.each do |request_sym, handler_name|
    request request_sym do |resource, handler_args|
      resource.property.fv.call("api."+handler_name, *handler_args.values.map(&:to_s))
    end
  end

  request :flowSpaces do |resource|
     results = resource.property.fv.call("api.listFlowSpace")
     results.map do |line|
       array = line.split(/FlowEntry\[|=\[|\],\]?/).reject(&:empty?)
       Hash[*array]
     end
  end
end
