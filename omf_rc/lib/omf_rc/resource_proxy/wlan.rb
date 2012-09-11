module OmfRc::ResourceProxy::Wlan
  include OmfRc::ResourceProxyDSL

  register_proxy :wlan

  utility :mod
  utility :iw
end
