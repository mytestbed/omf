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
    addr = CommandLine.new("ip", "addr show dev :device", :device => resource.property.if_name).run
    addr && addr.chomp.match(/inet ([[0-9]\:\/\.]+)/) && $1
  end

  # Retrieve MAC address
  #
  # @return [String] MAC address
  # @!macro request
  # @!method request_mac_addr
  request :mac_addr do |resource|
    addr = CommandLine.new("ip", "addr show dev :device", :device => resource.property.if_name).run
    addr && addr.chomp.match(/link\/ether ([\d[a-f][A-F]\:]+)/) && $1
  end

  request :state do |device|
    link = CommandLine.new("ip", "link show :device", :device => device.property.if_name).run
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
    CommandLine.new("ip",  "addr add :ip_address dev :device",
                    :ip_address => value,
                    :device => resource.property.if_name
                   ).run
    resource.interface_up
    resource.request_ip_addr
  end
  # @!endgroup

  # @!macro group_work
  # Bring up network interface
  # @!macro work
  # @!method interface_up
  work :interface_up do |resource|
    CommandLine.new("ip", "link set :dev up", :dev => resource.property.if_name).run
  end

  work :interface_down do |device|
    CommandLine.new("ip", "link set :dev down", :dev => device.property.if_name).run
  end

  # Remove IP addresses associated with the interface
  #
  # @!macro work
  # @!method flush_ip_addrs
  work :flush_ip_addrs do |resource|
    CommandLine.new("ip",  "addr flush dev :device",
                    :device => resource.property.if_name).run
  end
  # @!endgroup
end
