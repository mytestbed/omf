require 'hashie'
require 'omf_rc/util'

module OmfRc::ResourceProxy::Interface
  include OmfRc::ResourceProxy
  include OmfRc::Util

  register_proxy :interface
  utility :ifconfig

  IPTABLES = 'iptables'
  ROUTE = 'route'

  def configure_property(property, value)
    case property
    when /^forwarding$/
      OmfRc::Cmd.exec("echo #{value ? '1' : '0'} > /proc/sys/net/ipv4/conf/#{uid}/forwarding")
    when /^gateway$/
      # FIXME Not sure about this one, hard coded everything?
      OmfRc::Cmd.exec("route del default dev eth1; route add default gw #{value}; route add 224.10.10.6 dev eth1")
    when /^route$/
      value = Hashie::Mash.new(value)
      arguments = %w(net gw mask).map {|v| "-#{v} #{value.send(v)}" if value.send(v)}.join(' ')
      OmfRc::Cmd.exec("#{ROUTE} #{value.op} #{arguments} dev #{uid}")
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
      OmfRc::Cmd.exec("#{IPTABLES} #{operation} #{chain} #{protocol} #{chain}")
    else
      super
    end
  end
end
