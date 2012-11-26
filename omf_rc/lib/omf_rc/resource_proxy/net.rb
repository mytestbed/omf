module OmfRc::ResourceProxy::Net
  include OmfRc::ResourceProxyDSL

  register_proxy :net

  utility :ip
  utility :sysfs
end
