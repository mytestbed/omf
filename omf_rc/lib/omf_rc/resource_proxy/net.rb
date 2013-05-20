module OmfRc::ResourceProxy::Net
  include OmfRc::ResourceProxyDSL

  register_proxy :net

  utility :ip
  utility :sysfs

  property :if_name, :default => "eth0"
  property :phy
end
