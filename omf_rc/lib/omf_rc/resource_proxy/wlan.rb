module OmfRc::ResourceProxy::Wlan
  include OmfRc::ResourceProxyDSL

  register_proxy :wlan

  utility :ip
  utility :mod
  utility :iw
  utility :sysfs

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
