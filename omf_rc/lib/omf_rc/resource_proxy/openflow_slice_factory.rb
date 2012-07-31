require 'xmlrpc/client'

module OmfRc::ResourceProxy::OpenflowSliceFactory
  include OmfRc::ResourceProxyDSL

  FLOWVISOR_VERSION = "FV version=flowvisor-0.8.4"
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

  hook :before_ready do |resource|
    resource.property.fv_args = FLOWVISOR_DEFAULTS
    resource.config_fv
  end

  request :flowvisor do |resource|
    resource.property.fv_args
  end

  configure :flowvisor do |resource, fv_args|
    resource.property.fv_args.update(fv_args)
    resource.config_fv
    resource.property.fv_args
  end

  { :slices => "listSlices", :devices => "listDevices", :deviceInfo => "getDeviceInfo", :deviceStats => "getSwitchStats" }.each do |request_sym, handler_name|
    request request_sym do |resource, handler_args|
      begin
        result = resource.property.fv ? resource.property.fv.call("api."+handler_name, *handler_args.values.map(&:to_s)) : nil
      rescue Exception => bang
        result = nil
        logger.error "Request "+request_sym.to_s+" didn't succeed: "+bang.message
      end
      result
    end
  end

  request :flowSpaces do |resource|
    begin
      if ( result = resource.property.fv ? resource.property.fv.call("api.listFlowSpace") : nil )
        result.map do |line|
          array = line.split(/FlowEntry\[|=\[|\],\]?/).reject(&:empty?)
          Hash[*array]
        end
      end
    rescue Exception => bang 
      result = nil
      logger.error "Request flowSpaces didn't succeed: "+bang.message
    end
    result
  end

  work :config_fv do |resource|
    begin
      fv = XMLRPC::Client.new_from_hash(resource.property.fv_args)
      fv.instance_variable_get("@http").verify_mode = OpenSSL::SSL::VERIFY_NONE
      ping_msg = "ping"
      resource.property.fv = ( fv.call("api.ping", ping_msg) == ("PONG("+resource.property.fv_args[:user]+"): "+FLOWVISOR_VERSION+"::"+ping_msg) ) ? fv : nil
    rescue
      resource.property.fv = nil
      fv_args_str = resource.property.fv_args.map{|k,v| "#{k}=\"#{v}\""}.join(' ')
      logger.error "Connection with Flowvisor ["+fv_args_str+"] was not successful"
    end
  end

end
