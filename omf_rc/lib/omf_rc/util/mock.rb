module OmfRc::Util::Mock
  include OmfRc::ResourceProxyDSL

  register_utility :mock

  register_request :nothing do |resource|
    resource.uid
  end

  register_configure :nothing

  register_configure :hrn do |resource, hrn|
    resource.hrn = hrn
  end

  register_request :resource_proxy_list do
    OmfRc::ResourceFactory.proxy_list
  end

  register_request :resource_utility_list do
    OmfRc::ResourceFactory.utility_list
  end

  register_request :kernel_version do
    OmfCommon::Command.execute("uname -r")
  end
end
