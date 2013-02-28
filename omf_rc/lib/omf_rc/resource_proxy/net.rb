module OmfRc::ResourceProxy::Net
  include OmfRc::ResourceProxyDSL
  
  register_proxy :net
  property :if_name, :default => "eth0"
  utility :ip
  utility :sysfs
end
