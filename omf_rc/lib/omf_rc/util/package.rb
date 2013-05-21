# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

# Package management utility, could be included in application resource proxy
#
module OmfRc::ResourceProxy::Package
  include OmfRc::ResourceProxyDSL

  register_utility :package

  request :package_version do |resource|
    OmfCommon::Command.execute("dpkg -l #{resource.hrn} | awk 'END { print $3 }'")
  end

  configure :install_package do |resource|
    OmfCommon::Command.execute("apt-get install -y --reinstall --allow-unauthenticated -qq #{resource.hrn}")
  end

  configure :remove_package do |resource|
    OmfCommon::Command.execute("apt-get purge -y -qq #{resource.hrn}")
  end
end
