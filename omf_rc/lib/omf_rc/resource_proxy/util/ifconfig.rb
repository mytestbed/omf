module OmfRc
  module ResourceProxy
    module Util
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

