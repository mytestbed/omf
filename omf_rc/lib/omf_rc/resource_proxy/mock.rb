module OmfRc::ResourceProxy::Mock
  include OmfRc::ResourceProxyDSL

  register_proxy :mock

  utility :mock
end

