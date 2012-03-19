require 'omf_rc/resource_proxy/util/mod'
require 'omf_rc/resource_proxy/util/ifconfig'
require 'omf_rc/resource_proxy/util/iw'

module OmfRc::ResourceProxy::Wifi
  include OmfRc::ResourceProxy::Util::Mod
  include OmfRc::ResourceProxy::Util::Ifconfig
  include OmfRc::ResourceProxy::Util::Iw
end
