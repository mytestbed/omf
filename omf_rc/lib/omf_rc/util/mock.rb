module OmfRc::Util::Mock
  include OmfRc::ResourceProxyDSL

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

  request :kernel_version do
    OmfCommon::Command.execute("uname -r")
  end
end
