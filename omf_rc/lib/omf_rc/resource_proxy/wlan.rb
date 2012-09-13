module OmfRc::ResourceProxy::Wlan
  include OmfRc::ResourceProxyDSL

  register_proxy :wlan

  utility :ip
  utility :mod
  utility :iw
end
