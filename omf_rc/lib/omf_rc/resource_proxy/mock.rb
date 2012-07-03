module OmfRc::ResourceProxy::Mock
  include OmfRc::ResourceProxyDSL

  register_proxy :mock

  utility :mock

  hook :before_ready do |resource|
    logger.info "#{resource.uid} is now ready"
  end

  hook :before_release do |resource|
    logger.info "#{resource.uid} is to be released"
  end
end

