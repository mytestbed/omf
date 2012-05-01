require 'omf_rc/util'

module OmfRc::ResourceProxy::Wifi
  include OmfRc::Util

  utility :mod
  utility :ifconfig
  utility :iw
end
