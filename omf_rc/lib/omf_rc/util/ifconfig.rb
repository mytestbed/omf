module OmfRc::Util::Ifconfig

  IFCONFIG_CMD = "ifconfig"

  def configure_property(property, value)
    case property
    when /^ip$/
      OmfRc::Cmd.exec("#{IFCONFIG_CMD} #{uid} #{value} netmask 255.255.0.0")
    when /^(up|down)$/
      OmfRc::Cmd.exec("#{IFCONFIG_CMD} #{uid} #{property}")
    when /^(netmask|mtu)$/
      OmfRc::Cmd.exec("#{IFCONFIG_CMD} #{uid} #{property} #{value}")
    when /^mac$/
      OmfRc::Cmd.exec("#{IFCONFIG_CMD} #{uid} hw ether #{value}")
    when /^arp$/
      OmfRc::Cmd.exec("#{IFCONFIG_CMD} #{uid} #{'-' if value}arp")
    else
      super
    end
  end

  def request_property(property)
    case property
    when /^mac$/
      OmfRc::Cmd.exec(IFCONFIG_CMD).match(/([\da-fA-F]+:){5}[\da-fA-F]+/) && $&
    when /^ip$/
      OmfRc::Cmd.exec(IFCONFIG_CMD).match(/([.\d]+\.){3}[.\d]+/) && $&
    else
      super
    end
  end
end

