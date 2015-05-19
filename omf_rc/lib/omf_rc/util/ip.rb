# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'cocaine'

module OmfRc::Util::Ip
  include OmfRc::ResourceProxyDSL
  include Cocaine

  # @!macro extend_dsl

  # @!macro group_request
  # Retrieve IP address
  #
  # @return [String] IP address
  # @!macro request
  # @!method request_ip_addr
  request :ip_addr do |resource|
    c = CommandLine.new("ip", "addr show dev :device")
    addr = c.run( { :device => resource.property.if_name })
    addr && addr.chomp.match(/inet ([[0-9]\:\/\.]+)/) && $1
  end

  # Retrieve MAC address
  #
  # @return [String] MAC address
  # @!macro request
  # @!method request_mac_addr
  request :mac_addr do |resource|
    c = CommandLine.new("ip", "addr show dev :device")
    addr = c.run( { :device => resource.property.if_name })
    addr && addr.chomp.match(/link\/ether ([\d[a-f][A-F]\:]+)/) && $1
  end

  request :state do |device|
    c = CommandLine.new("ip", "link show :device")
    link = c.run({ :device => device.property.if_name })
    link && link.chomp.match(/state (\w+) /) && $1
  end

  # @!endgroup

  # @!macro group_configure
  # Configure IP address
  #
  # @param value value of IP address, it should have netmask. (e.g. 0.0.0.0/24)
  #
  # @raise [ArgumentError] if provided no IP address or incorrect format
  #
  # @return [String] IP address
  # @!macro configure
  # @!method configure_ip_addr
  configure :ip_addr do |resource, value|
    if value.nil? || value.split('/')[1].nil?
      raise ArgumentError, "You need to provide a netmask with the IP address, e.g. #{value}/24. Got #{value}."
    end
    # Remove all ip addrs associated with the device
    resource.flush_ip_addrs
    c=CommandLine.new("ip",  "addr add :ip_address dev :device")
    c.run({ :ip_address => value,
            :device => resource.property.if_name })

    resource.interface_up
    resource.request_ip_addr
  end
  # @!endgroup

  # @!macro group_work
  # Bring up network interface
  # @!macro work
  # @!method interface_up
  work :interface_up do |resource|
    c=CommandLine.new("ip", "link set :dev up")
    c.run({ :dev => resource.property.if_name })
  end

  work :interface_down do |device|
    c=CommandLine.new("ip", "link set :dev down")
    c.run({ :dev => device.property.if_name })
  end

  # Remove IP addresses associated with the interface
  #
  # @!macro work
  # @!method flush_ip_addrs
  work :flush_ip_addrs do |resource|
    c=CommandLine.new("ip",  "addr flush dev :device")
    c.run({ :device => resource.property.if_name })
  end
  # @!endgroup
end
