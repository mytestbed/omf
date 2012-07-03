module OmfRc::ResourceProxy::Node
  include OmfRc::ResourceProxyDSL

  register_proxy :node

  hook :before_ready do |resource|
    logger.info "#{resource.uid} is now ready"
  end

  hook :before_release do |resource|
    logger.info "#{resource.uid} is now released"
  end

  request :proxies do
    OmfRc::ResourceFactory.proxy_list
  end
end
