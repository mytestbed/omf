module OmfRc::ResourceProxy::Node
  include OmfRc::ResourceProxyDSL

  register_proxy :node

  register_hook :before_ready do |resource|
    logger.info "#{resource.uid} is now ready"
  end

  register_hook :before_release do |resource|
    logger.info "#{resource.uid} is now released"
  end
end
