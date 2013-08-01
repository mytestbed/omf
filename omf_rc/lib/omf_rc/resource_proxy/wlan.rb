# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

# Proxy module for managing wifi devices
#
# Wlan resources can be created as children of {OmfRc::ResourceProxy::Node}.
#
# It is important to set if_name (interface_name) and phy (physical device name) as they are used as identifier for executing iw and ip commands.
#
# @example Set up a wifi interface wlan0 as managed mode
#   wlan0 = node.create(:wlan, if_name: 'wlan0', phy: 'phy0')
#   wlan0.configure_mode(mode: :master, hw_mode: 'g', channel: 1, essid: 'bob')
#
# @example Configure IP address of interface wlan0
#   wlan0.conifgure_ip_addr("192.168.1.100/24")
#
# @see OmfRc::Util::Iw
module OmfRc::ResourceProxy::Wlan
  include OmfRc::ResourceProxyDSL
  # @!macro extend_dsl

  register_proxy :wlan

  # @!parse include OmfRc::Util::Iw
  # @!parse include OmfRc::Util::Mod
  # @!parse include OmfRc::Util::Sysfs
  utility :iw
  utility :mod
  utility :sysfs

  # @!macro group_prop
  #
  # @!attribute [rw] if_name
  #   Interface name, default is 'wlan0'
  #   @!macro prop
  property :if_name, :default => "wlan0"
  # @!attribute [rw] phy
  #   Device's physical name
  #   @!macro prop
  property :phy

  # @!endgroup

  # @!macro group_hook
  #
  # Stop hostapd or wpa instances before releasing wifi device
  # @!macro hook
  # @!method before_release
  hook :before_release do |device|
    case device.property.mode.to_sym
    when :master
      device.stop_hostapd
    when :managed
      device.stop_wpa
    end
    #TODO need to remove all virtual interfaces of that phy device
    #device.remove_all_interfaces
  end
  # @!endgroup
end
