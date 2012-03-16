require 'hashie'

module OmfRc
  module ResourceProxy
    module Interface

      IFCONFIG = 'ifconfig'
      IPTABLES = 'iptables'
      ROUTE = 'route'

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
        when /^gateway$/
          # FIXME Not sure about this one, hard coded everything?
          `route del default dev eth1; route add default gw #{value}; route add 224.10.10.6 dev eth1`
        when /^route$/
          value = Hashie::Mash.new(value)
          arguments = %w(net gw mask).map {|v| "-#{v} #{value.send(v)}" if value.send(v)}.join(' ')
          `#{ROUTE} #{value.op} #{arguments} dev #{uid}`
        when /^filter$/
          operation = case value.op
                      when /^add$/
                        '-A'
                      when /^del$/
                        '-D'
                      when /^clear$/
                        '-F'
                      end
        chain = "#{value.chain.upcase} -i #{uid}" if value.chain
        protocol = case value.proto
                   when /^(tcp|udp)$/
                     [ ("-p #{value.proto}"),
                       ("-s #{value.src}" if value.src),
                       ("-d #{value.dst}" if value.dst),
                       ("--sport #{value.sport}" if value.sport),
                       ("--dport #{value.dport}" if value.dport) ].join(' ')
                   when /^mac$/
                     "-m mac --mac-source #{value.src}"
                   end
        target = "#{value.target.upcase}" if value.target
        `#{IPTABLES} #{operation} #{chain} #{protocol} #{chain}`
        else
          super
        end
      end

      def request_property(property)
        case property
        when /^mac$/
          `#{IFCONFIG} #{uid}`.match(/([\da-fA-F]+:){5}[\da-fA-F]+/) && $&
        when /^ip$/
          `#{IFCONFIG} #{uid}`.match(/([.\d]+\.){3}[.\d]+/) && $&
        else
          super
        end
      end
    end
  end
end
