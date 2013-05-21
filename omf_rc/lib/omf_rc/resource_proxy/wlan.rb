# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfRc::ResourceProxy::Wlan
  include OmfRc::ResourceProxyDSL

  register_proxy :wlan

  utility :ip
  utility :mod
  utility :iw
  utility :sysfs

  property :if_name, :default => "wlan0"
  property :phy

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
end
