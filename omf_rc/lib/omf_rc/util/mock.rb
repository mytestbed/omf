# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfRc::Util::Mock
  include OmfRc::ResourceProxyDSL

  request :nothing do |resource|
    resource.uid
  end

  configure :nothing do
  end

  configure :hrn do |resource, hrn|
    resource.hrn = hrn
  end

  request :resource_proxy_list do
    OmfRc::ResourceFactory.proxy_list
  end

  request :kernel_version do
    OmfCommon::Command.execute("uname -r")
  end
end
