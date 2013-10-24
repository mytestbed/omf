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
module OmfRc::ResourceProxy::WiMax
  include OmfRc::ResourceProxyDSL
  # @!macro extend_dsl

  register_proxy :wimax

  # @!parse include OmfRc::Util::Iw
  # @!parse include OmfRc::Util::Mod
  # @!parse include OmfRc::Util::Sysfs
  #utility :iw
  #utility :mod
  #utility :sysfs

  # @!macro group_prop
  #
  # @!attribute [rw] if_name
  #   Interface name, default is 'wlan0'
  #   @!macro prop
  property :if_name, :default => "tel0"
  # @!attribute [rw] phy
  #   Device's physical name
  #   @!macro prop
  property :phy

  property :mode
  property :ip
  property :subnet
  property :nm
  property :gw

  hook :before_ready do |device|
    #@mode = @ip = @subnet = @nm = @gw = nil
    @ifconfig = '/sbin/ifconfig'
    @wget = '/usr/bin/wget'
    @route = '/sbin/route'
    @deldef = false
    puts "before ready"
    IO.popen("#{@ifconfig} #{deviceName} 192.168.0.8 netmask 255.255.255.0")
  end

  # @!endgroup

  # @!macro group_hook
  #
  # Stop hostapd or wpa instances before releasing wifi device
  # @!macro hook
  # @!method before_release
  #hook :before_release do |device|
  #  case device.property.mode.to_sym
  #  when :master
  #    device.stop_hostapd
  #  when :managed
  #    device.stop_wpa
  #  end
  #  #TODO need to remove all virtual interfaces of that phy device
  #  #device.remove_all_interfaces
  #end
  # @!endgroup
end
