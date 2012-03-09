require 'hashie'

module OmfRc::ResourceProxy
  module Interface

    IFCONFIG = `which ifconfig`
    ROUTE = `which route`
    DEVICE = uid

    def configure_property(property, value)
      case property
      when /^ip$/
        `#{IFCONFIG} #{DEVICE} #{value} netmask 255.255.0.0`
      when /^(up|down)$/
        `#{IFCONFIG} #{DEVICE} #{property}`
      when /^(netmask|mtu)$/
        `#{IFCONFIG} #{DEVICE} #{property} #{value}`
      when /^mac$/
        `#{IFCONFIG} #{DEVICE} hw ether #{value}`
      when /^arp$/
        `#{IFCONFIG} #{DEVICE} #{'-' if value}arp`
      when /^forwarding$/
        `echo #{value ? '1' : '0'} > /proc/sys/net/ipv4/conf/#{DEVICE}/forwarding`
      when /^gateway$/
        # FIXME Not sure about this one, hard coded everything?
        `route del default dev eth1; route add default gw #{value}; route add 224.10.10.6 dev eth1`
      when /^route$/
        value = Hashie::Mash.new(value)
        arguments = %w(net gw mask).map {|v| "-#{v} #{value.send(v)}" if value.send(v)}.join(' ')
        `#{ROUTE} #{value.op} #{arguments} dev #{uid}`
      when /^filter$/
      else
        super
      end
    end

    def request_property(property)
      case property
      when /mac/
        `#{IFCONFIG} #{DEVICE}`.match(/([\da-fA-F]+:){5}[\da-fA-F]+/).to_s
      when /ip/
        `#{IFCONFIG} #{DEVICE}`.match(/([.\d]+\.){3}[.\d]+/).to_s
      else
        super
      end
    end
  end
end
