require 'omf_rc/resource_proxy/abstract'

module OmfRc::ResourceProxy
  class NetworkInterface < Abstract
    PROPERTIES = %w(ip up down netmask mtu mac arp forwarding)
    IFCONFIG = 'ifconfig'

    def validate
      super
      invalid_properties = Hashie::Mash.new(properties).keys - PROPERTIES
      puts invalid_properties
      errors.add(:properties, "Invalid property #{invalid_properties.join(', ')}") unless invalid_properties.empty?
    end

    def configure_property(property, value)
      configure_command = case property.to_sym
                          when :ip
                            "#{IFCONFIG} #{uid} #{value} netmask 255.255.0.0"
                          when :up
                            "#{IFCONFIG} #{uid} up"
                          when :down
                            "#{IFCONFIG} #{uid} down"
                          when :netmask
                            "#{IFCONFIG} #{uid} netmask #{value}"
                          when :mtu
                            "#{IFCONFIG} #{uid} mtu #{value}"
                          when :mac
                            "#{IFCONFIG} #{uid} hw ether #{value}"
                          when :arp
                            "#{IFCONFIG} #{uid} #{'-' if value}arp"
                          when :forwarding
                            "echo #{value ? '1' : '0'} > /proc/sys/net/ipv4/conf/#{uid}/forwarding"
                          end
      system(configure_command) && super
    end

    def request_property(property)
      pattern = case property.to_sym
                when :mac then /(.{2}:){5}.{2}/
                when :ip then /([.\d]+\.){3}[.\d]+/
                else
                  super
                end
      lines = IO.popen("#{IFCONFIG} #{uid}", "r").readlines
      lines.join("").match(pattern)[0] rescue nil
    end
  end
end
