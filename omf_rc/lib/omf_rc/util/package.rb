# Package management utility, could be included in application resource proxy
#
module OmfRc::ResourceProxy::Package
  include OmfRc::ResourceProxyDSL

  register_utility :package

  register_request :package_version do |resource|
    OmfCommon::Command.execute("dpkg -l #{resource.hrn} | awk 'END { print $3 }'")
  end

  register_configure :install_package do |resource|
    OmfCommon::Command.execute("apt-get install -y --reinstall --allow-unauthenticated -qq #{resource.hrn}")
  end

  register_configure :remove_package do |resource|
    OmfCommon::Command.execute("apt-get purge -y -qq #{resource.hrn}")
  end
end
