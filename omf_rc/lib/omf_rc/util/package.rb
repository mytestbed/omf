module OmfRc::ResourceProxy::Package
  include OmfRc::ResourceProxyDSL

  register_utility :package

  register_request :package_version do |callback|
    OmfRc::Cmd.exec("dpkg -l #{hrn} | awk 'END { print $3 }'", &callback)
  end

  register_configure :install_package do |callback|
    OmfRc::Cmd.exec("apt-get install -y --reinstall --allow-unauthenticated -qq #{hrn}", &callback)
  end

  register_configure :remove_package do |callback|
    OmfRc::Cmd.exec("apt-get purge -y -qq #{hrn}", &callback)
  end
end
