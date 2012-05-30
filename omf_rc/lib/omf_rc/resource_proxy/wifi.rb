module OmfRc::ResourceProxy::Wifi
  include OmfRc::ResourceProxyDSL

  register_proxy :wifi

  utility :mod
  utility :iw
end
