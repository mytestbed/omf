module OmfRc::Util::Mock
  include OmfRc::ResourceProxyDSL

  register_utility :mock

  register_request :bob do
    "Very important property's value"
  end

  register_request :kernel_version do |callback|
    OmfRc::Cmd.exec("uname -r", &callback)
  end
end
