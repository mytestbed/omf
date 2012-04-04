require 'omf_rc/resource_proxy/util'

module OmfRc::ResourceProxy::Wifi
  include OmfRc::ResourceProxy::Util

  utility :mod
  utility :ifconfig
  utility :iw
end
