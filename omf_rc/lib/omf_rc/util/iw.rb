# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'hashie'
require 'cocaine'

# Utility for executing command 'iw'
module OmfRc::Util::Iw
  include OmfRc::ResourceProxyDSL

  include Cocaine
  include Hashie

  # @!macro extend_dsl
  #
  # @!parse include OmfRc::Util::Ip
  # @!parse include OmfRc::Util::Wpa
  # @!parse include OmfRc::Util::Hostapd
  utility :ip
  utility :wpa
  utility :hostapd

  # Parse iw help page and set up all configure methods available for iw command
  #
  begin
    CommandLine.new("iw", "help").run.chomp.gsub(/^\t/, '').split("\n").map {|v| v.match(/[phy|dev] <.+> set (\w+) .*/) && $1 }.compact.uniq.each do |p|
      next if p == 'type'
      configure p do |device, value|
        c=CommandLine.new("iw", "dev :dev set :property :value")
        c.run ({        :dev => device.property.if_name,
                        :property => p,
                        :value => value      })
      end
    end
  rescue Cocaine::CommandNotFoundError
    logger.warn "Command iw not found"
  end

  # @!macro group_request
  #
  # Parse iw link command output and return as a mash
  #
  # @example return value
  #
  #   { ssid: 'ap', freq: '2412', signal: '-67 dBm' }
  #
  # @return [Mash]
  #
  # @!method request_link
  # @!macro request
  request :link do |device|
    known_properties = Mash.new

    command = CommandLine.new("iw", "dev :dev link")

    command.run({ :dev => device.property.if_name }).chomp.gsub(/^\t/, '').split("\n").drop(1).each do |v|
      v.match(/^(.+):\W*(.+)$/).tap do |m|
        m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
      end
    end

    known_properties
  end

  # Parse iw info command output and return as a mash
  #
  # @example return value
  #
  #   { ifindex: '3', type: 'managed', wiphy: '0' }
  #
  # @return [Mash]
  # @!method request_info
  # @!macro request
  request :info do |device|
    known_properties = Mash.new

    command = CommandLine.new("iw", "dev :dev info")

    command.run({ :dev => device.property.if_name }).chomp.split("\n").drop(1).each do |v|
      v.match(/^\W*(.+) (.+)$/).tap do |m|
        m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
      end
    end

    known_properties
  end

  # @!endgroup

  # @!macro group_configure
  #
  # Configure the interface with mode: managed, master, adhoc or monitor
  #
  # @example Sample opts for mode property
  #   # Master
  #   { mode: :master, hw_mode: 'a', channel: 1, essid: 'bob' }
  #
  #   # Managed
  #   { mode: :managed, essid: 'bob' }
  #
  #   # Ad-hoc
  #   { mode: :adhoc, essid: 'bob', frequency: 2412 }
  #
  #   # Monitor
  #   { mode: :monitor }
  #
  # @param [Hash] opts the hash to set up mode of wireless interface
  #
  # @option opts [Symbol] :mode wireless connection mode (:master, :managed, :adhoc)
  # @option opts [Symbol] :hw_mode wireless connection hardware mode ('a', 'b', 'g', 'n')
  # @option opts [Symbol] :essid
  # @option opts [Symbol] :channel
  # @option opts [Symbol] :frequency
  #
  # @raise [ArgumentError] if wifi device specified cannot be found on the system
  #
  # @return [String] ip address of the device if configured properly
  #
  # @!method configure_mode(opts)
  # @!macro configure
  configure :mode do |device, opts|
    # capture opts hash and store internally
    device.property.update(opts)

    if device.property.phy && device.property.phy =~ /^%(\d+)%$/
      wlan_phy_device = device.request_wlan_devices[$1.to_i]
      if wlan_phy_device
        device.property.phy = wlan_phy_device[:name]
      else
        raise ArgumentError, "Could not find your wifi device no #{$1.to_i}"
      end
    end

    device.validate_iw_properties

    device.delete_interface rescue logger.warn "Interface #{device.property.if_name} not found"

    # TODO should just remove all interfaces from physical device, at least make it optional

    case device.property.mode.to_sym
    when :master
      device.add_interface(:managed)
      device.hostapd
    when :managed
      device.add_interface(:managed)
      device.wpasup
    when :adhoc
      device.add_interface(:adhoc)
      device.interface_up
      device.join_ibss
    when :monitor
      device.add_interface(:monitor)
      device.interface_up
    end

    device.configure_ip_addr(device.property.ip_addr) if device.property.ip_addr
  end

  # @!endgroup
  #
  # @!macro group_work
  #
  # Delete current interface, clean up
  #
  # @return [String] iw command output
  # @!macro work
  work :delete_interface do |device|
    c=CommandLine.new("iw", "dev :dev del")
    c.run({  :dev => device.property.if_name })
  end

  # Add interface to device
  #
  # @return [String] iw command output
  # @!macro work
  work :add_interface do |device, type|
    c=CommandLine.new("iw", "phy :phy interface add :dev type :type")
    c.run( {
                    :phy => device.property.phy,
                    :dev => device.property.if_name,
                    :type => type.to_s })
  end

  # Set up or join a ibss network
  #
  # @return [String] iw command output
  # @!macro work
  work :join_ibss do |device|
    c=CommandLine.new("iw", "dev :device ibss join :essid :frequency")
    c.run( {
                      :device => device.property.if_name.to_s,
                      :essid => device.property.essid.to_s,
                      :frequency => device.property.frequency.to_s  })
  end

  # Validate internal properties based on interface mode
  #
  # @raise [ArgumentError] if validation failed
  #
  # @return [nil]
  # @!macro work
  work :validate_iw_properties do |device|
    raise ArgumentError, "Missing phyical device name" if device.property.phy.nil?

    unless %w(master managed adhoc monitor).include? device.property.mode
      raise ArgumentError, "Mode must be master, managed, adhoc, or monitor, got #{device.property.mode}"
    end

    case device.property.mode.to_sym
    when :master
      unless %w(a b g n).include? device.property.hw_mode
        raise ArgumentError, "Hardware mode must be a, b, g, or n, got #{device.property.hw_mode}"
      end
      %w(channel essid).each do |p|
        raise ArgumentError, "#{p} must not be nil" if device.property.send(p).nil?
      end
    when :managed
      %w(essid).each do |p|
        raise ArgumentError, "#{p} must not be nil" if device.property.send(p).nil?
      end
    when :adhoc
      %w(essid frequency).each do |p|
        raise ArgumentError, "#{p} must not be nil" if device.property.send(p).nil?
      end
    end
  end

  # @!endgroup
end
