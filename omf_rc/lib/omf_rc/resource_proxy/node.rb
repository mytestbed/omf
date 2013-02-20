module OmfRc::ResourceProxy::Node
  include OmfRc::ResourceProxyDSL

  register_proxy :node

  utility :mod
  utility :sysfs

  request :proxies do
    OmfRc::ResourceFactory.proxy_list
  end

  request :interfaces do |node|
    node.children.find_all { |v| v.type == :net || v.type == :wlan }.map do |v|
      { name: v.hrn, type: v.type, uid: v.uid }
    end.sort { |x, y| x[:name] <=> y[:name] }
  end

  request :applications do |node|
    node.children.find_all { |v| v.type =~ /application/ }.map do |v|
      { name: v.hrn, type: v.type, uid: v.uid }
    end.sort { |x, y| x[:name] <=> y[:name] }
  end

end
