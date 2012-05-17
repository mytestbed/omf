module OmfRc::Util::Mock
  include OmfRc::ResourceProxyDSL

  register_utility :mock

  register_request :nothing
  register_configure :nothing

  register_request :resource_proxy_list do |callback|
    callback.call(success: OmfRc::ResourceFactory.proxy_list)
  end

  register_request :resource_utility_list do |callback|
    callback.call(success: OmfRc::ResourceFactory.utility_list)
  end

  register_request :kernel_version do |callback|
    OmfRc::Cmd.exec("uname -r", &callback)
  end
end
