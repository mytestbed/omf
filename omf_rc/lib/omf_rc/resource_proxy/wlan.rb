module OmfRc::ResourceProxy::Wifi
  include OmfRc::ResourceProxyDSL

  register_proxy :wlan

  utility :mod
  utility :iw
end
