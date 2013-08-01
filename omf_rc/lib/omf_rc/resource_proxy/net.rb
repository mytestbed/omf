# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

# Proxy for managing Ethernet interfaces
#
# Net resources can be created as children of {OmfRc::ResourceProxy::Node}.
#
# It is important to set if_name (interface_name) as they are used as identifier for executing ip commands.
#
# @example Bring up an Ethernet interface eth0 by setting an ip address
#   eth0 = node.create(:wlan, if_name: 'eth0')
#   eth0.conifgure_ip_addr("192.168.1.100/24")
#
# @see OmfRc::Util::Ip
module OmfRc::ResourceProxy::Net
  include OmfRc::ResourceProxyDSL
  # @!macro extend_dsl

  register_proxy :net

  # @!parse include OmfRc::Util::Ip
  # @!parse include OmfRc::Util::Sysfs
  utility :ip
  utility :sysfs

  # @!macro group_prop
  #
  # @!attribute [rw] if_name
  #   Interface name, default is 'eth0'.
  #   @!macro prop
  property :if_name, :default => "eth0"
  # @!endgroup
end
