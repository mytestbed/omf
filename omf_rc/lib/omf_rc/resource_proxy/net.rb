# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfRc::ResourceProxy::Net
  include OmfRc::ResourceProxyDSL

  register_proxy :net

  utility :ip
  utility :sysfs

  property :if_name, :default => "eth0"
  property :phy
end
