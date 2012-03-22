require 'omf_rc/resource_proxy/util'

module OmfRc::ResourceProxy::Wifi
  include OmfRc::ResourceProxy::Util::Mod
  include OmfRc::ResourceProxy::Util::Ifconfig
  include OmfRc::ResourceProxy::Util::Iw
end
