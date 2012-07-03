module OmfRc::Util::Mock
  include OmfRc::ResourceProxyDSL

  register_utility :mock

  request :nothing do |resource|
    resource.uid
  end

  configure :nothing

  configure :hrn do |resource, hrn|
    resource.hrn = hrn
  end

  request :resource_proxy_list do
    OmfRc::ResourceFactory.proxy_list
  end

  request :resource_utility_list do
    OmfRc::ResourceFactory.utility_list
  end

  request :kernel_version do
    OmfCommon::Command.execute("uname -r")
  end
end
