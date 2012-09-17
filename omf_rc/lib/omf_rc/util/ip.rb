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
    CommandLine.new("ip",  "addr add :ip_address dev :device",
                    :ip_address => value,
                    :device => resource.hrn
                   ).run
    resource.request_ip_addr
  end
end
