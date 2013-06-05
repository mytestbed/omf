# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

# Getting available hardware by browsing sysfs directories
module OmfRc::Util::Sysfs
  include OmfRc::ResourceProxyDSL
  # @!macro extend_dsl

  # @!macro group_request
  # @!macro request
  # @!method request_devices
  #
  # @example Sample return value
  #   [
  #     { name: 'eth0', driver: 'e1000e', category: 'net', proxy: 'net' },
  #     { name: 'phy0', driver: 'iwlwifi', category: 'net', subcategory: 'wlan', proxy: 'wlan' } ]
  request :devices do |resource|
    devices = []
    # Support net devices for now
    category = "net"

    Dir.glob("/sys/class/net/eth*").each do |v|
      File.exist?("#{v}/uevent") && File.open("#{v}/uevent") do |f|
        subcategory = f.read.match(/DEVTYPE=(.+)/) && $1
        proxy = "net"
        File.exist?("#{v}/device/uevent") && File.open("#{v}/device/uevent") do |f|
          driver = f.read.match(/DRIVER=(.+)/) && $1
          device = { name: File.basename(v), driver: driver, category: category }
          device[:subcategory] = subcategory if subcategory
          device[:proxy] = proxy if OmfRc::ResourceFactory.proxy_list.include?(proxy.to_sym)
          File.exist?("#{v}/operstate") && File.open("#{v}/operstate") do |fo|
            device[:op_state] = (fo.read || '').chomp
          end
          # Let's see if the interface is already up
          # NOTE: THIS MAY NOT BE ROBUST
          s = `ifconfig #{File.basename(v)}`
          unless s.empty?
            if m = s.match(/inet addr:\s*([0-9.]+)/)
              device[:ip4] = m[1]
            end
            if m = s.match(/inet6 addr:\s*([0-9a-f.:\/]+)/)
              device[:ip6] = m[1]
            end
          end
          devices << device
        end
      end
    end

    Dir.glob("/sys/class/ieee80211/*").each do |v|
      subcategory = "wlan"
      proxy = "wlan"
      File.exist?("#{v}/device/uevent") && File.open("#{v}/device/uevent") do |f|
        driver = f.read.match(/DRIVER=(.+)/) && $1
        device = { name: File.basename(v), driver: driver, category: category, subcategory: subcategory }
        device[:proxy] = proxy if OmfRc::ResourceFactory.proxy_list.include?(proxy.to_sym)
        devices << device
      end
    end
    devices
  end

  # @!macro request
  # @!method request_wlan_devices
  #
  # @example Sample return value
  #   [ { name: 'phy0', driver: 'iwlwifi', category: 'net', subcategory: 'wlan', proxy: 'wlan' } ]
  request :wlan_devices do |resource|
    resource.request_devices.find_all { |v| v[:proxy] == 'wlan' }
  end
end

