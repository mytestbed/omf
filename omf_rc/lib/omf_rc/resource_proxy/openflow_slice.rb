require 'xmlrpc/client'
require 'omf_common'

module OmfRc::ResourceProxy::OpenflowSlice
  include OmfRc::ResourceProxyDSL
  
  SLICE_DEFAULTS = {
    :passwd=>"1234",
    :url=>"tcp:127.0.0.1",
    :email=>"nobody@nowhere"
  }

  register_proxy :openflow_slice

  hook :before_ready do |resource|
    resource.property.name = nil
  end

  hook :before_release do |resource|
    begin
      resource.property.fv.call("api.deleteSlice", resource.property.name)
    rescue Exception
      raise "Flowvisor instance does not respond normally"
    end
  end

  configure :name do |resource, name|
    raise "The name of this slice has already been configured" if resource.property.name
    resource.property.name = name
    begin
      resource.property.fv.call("api.createSlice", name, *SLICE_DEFAULTS.values)
    rescue XMLRPC::FaultException
      raise "Flowvisor cannot create slice with existing name"
    rescue Exception
      raise "Flowvisor instance does not respond normally"
    end
  end

  request :info do |resource|
    begin
      result = resource.property.fv.call("api.getSliceInfo", resource.property.name)
      logger.info result
      result[:name] = resource.property.name
      result
    rescue Exception
      raise "Flowvisor instance does not respond normally"
    end
  end

  request :stats do |resource|
    begin
      resource.property.fv.call("api.getSliceStats", resource.property.name)
    rescue Exception
      raise "Flowvisor instance does not respond normally"
    end
  end

  { :passwd => "changePasswd", :change => "changeSlice" }.each do |configure_sym, handler_name|
    configure configure_sym do |resource, handler_args|
      begin
        resource.property.fv.call("api."+handler_name, resource.property.name, *handler_args.values.map(&:to_s))
      rescue Exception
        raise "Flowvisor instance does not respond normally"
      end
    end
  end

  [ :addFlowSpace, :removeFlowSpace , :changeFlowSpace ].each do |configure_sym|
    configure configure_sym do |resource, handler_args|
      str = configure_sym.to_s
      str.slice!("FlowSpace")
      handler_args["operation"] = str.upcase
      begin
        resource.property.fv.call("api.changeFlowSpace", [handler_args.each_with_object({}) { |(k, v), h| h[k] = v.to_s }])
      rescue Exception
        raise "Flowvisor instance does not respond normally"
      end
    end
  end
end
