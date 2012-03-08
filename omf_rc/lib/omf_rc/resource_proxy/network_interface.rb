require 'omf_rc/resource_proxy/abstract'

module OmfRc::ResourceProxy
  module Interface

    IFCONFIG = 'ifconfig'

    def configure_property(property, value)
      case property
      when /^ip$/
        `#{IFCONFIG} #{uid} #{value} netmask 255.255.0.0`
      when /^(up|down)$/
        `#{IFCONFIG} #{uid} #{property}`
      when /^(netmask|mtu)$/
        `#{IFCONFIG} #{uid} #{property} #{value}`
      when /^mac$/
        `#{IFCONFIG} #{uid} hw ether #{value}`
      when /^arp$/
        `#{IFCONFIG} #{uid} #{'-' if value}arp`
      when /^forwarding$/
        `echo #{value ? '1' : '0'} > /proc/sys/net/ipv4/conf/#{uid}/forwarding`
      else
        super
      end
    end

    def request_property(property)
      case property
      when /mac/
        `#{IFCONFIG} #{uid}`.match(/(.{2}:){5}.{2}/).to_s
      when /ip/
        `#{IFCONFIG} #{uid}`.match(/([.\d]+\.){3}[.\d]+/).to_s
      else
        super
      end
    end
  end
end
