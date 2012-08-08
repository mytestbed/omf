require 'xmlrpc/client'
require 'omf_common'

# The "Openflow Slice" resource is created from the parent "Openflow Slice Factory" resource.
# It is related with a slice of a Flowvisor instance, and behaves as a proxy between experimenter and the actual Flowvisor slice.
# So, the whole state of the slice is keeped in the Flowvisor instance.
# The communication with Flowvisor is established from the parent resource, and it is included in the resource property "fv".
#
module OmfRc::ResourceProxy::OpenflowSlice
  include OmfRc::ResourceProxyDSL
  
  # The default parameters of a new created slice. The controller is assumed to be in the same working station with Flowvisor instance 
  SLICE_DEFAULTS = {
    :passwd=>"1234",
    :url=>"tcp:127.0.0.1",
    :email=>"nobody@nowhere"
  }

  register_proxy :openflow_slice

  # Slice's name is initiated with value "nil"
  hook :before_ready do |resource|
    resource.property.name = nil
  end

  # Before release the related Flowvisor instance should also be update to remove the corresponding slice
  hook :before_release do |resource|
    begin
      resource.property.fv.call("api.deleteSlice", resource.property.name)
    rescue Exception
      raise "Flowvisor instance does not respond normally"
    end
  end

  # The name is allowed to be one-time configured. Once it is configured, a new slice is created in Flowvisor instance
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

  # Returns a hash table with the name of this slice, its controller (ip and port) and other related information
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

  # Returns a string with statistics about the use of this slice
  request :stats do |resource|
    begin
      resource.property.fv.call("api.getSliceStats", resource.property.name)
    rescue Exception
      raise "Flowvisor instance does not respond normally"
    end
  end

  # Configures the slice parameters
  { :passwd => "changePasswd", :change => "changeSlice" }.each do |configure_sym, handler_name|
    configure configure_sym do |resource, handler_args|
      begin
        resource.property.fv.call("api."+handler_name, resource.property.name, *handler_args.values.map(&:to_s))
      rescue Exception
        raise "Flowvisor instance does not respond normally"
      end
    end
  end

  # Configures the flow spaces that this slice controls. 
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
