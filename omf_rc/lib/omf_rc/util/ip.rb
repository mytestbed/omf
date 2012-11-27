require 'cocaine'

module OmfRc::Util::Ip
  include OmfRc::ResourceProxyDSL
  include Cocaine

  request :ip_addr do |resource|
    addr = CommandLine.new("ip", "addr show dev :device", :device => resource.hrn).run
    addr && addr.chomp.match(/inet ([[0-9]\:\/\.]+)/) && $1
  end

  request :mac_addr do |resource|
    addr = CommandLine.new("ip", "addr show dev :device", :device => resource.hrn).run
    addr && addr.chomp.match(/link\/ether ([\d[a-f][A-F]\:]+)/) && $1
  end

  configure :ip_addr do |resource, value|
    # Remove all ip addrs associated with the device
    resource.flush_ip_addrs
    CommandLine.new("ip",  "addr add :ip_address dev :device",
                    :ip_address => value,
                    :device => resource.hrn
                   ).run
    resource.interface_up
    resource.request_ip_addr
  end

  work :interface_up do |resource|
    CommandLine.new("ip", "link set :dev up", :dev => resource.hrn).run
  end

  work :flush_ip_addrs do |resource|
    CommandLine.new("ip",  "addr flush dev :device",
                    :device => resource.hrn).run
  end
end
