require 'omf_rc/resource_proxy/util/mod'
require 'omf_rc/resource_proxy/util/ifconfig'
require 'omf_rc/resource_proxy/util/iw'

module OmfRc::ResourceProxy::Intel
  include OmfRc::ResourceProxy::Util::Mod
  include OmfRc::ResourceProxy::Util::Ifconfig
  include OmfRc::ResourceProxy::Util::Iw

  IWCONFIG = 'iwconfig'
  IWPRIV = 'iwpriv'

  def configure_property(property, value)
    property.gsub!(/tx_power/, 'txpower')
    case property
    when /^type$/
      type_numeric = %w(a b g).index(value)
      type_numeric = type_numeric && type_numeric + 1
      OmfRc::Cmd.exec("#{IWPRIV} #{uid} set_mode #{type_numeric}")
    when /^mode$/
      value.downcase!.gsub!(/adhoc/, 'ad-hoc')
      if value =~ /^(managed|master|monitor|ad-hoc)$/
        OmfRc::Cmd.exec("#{IWCONFIG} #{uid} mode #{$+} essid dummy channel 1")
      end
    when /^(essid|frequency|txpower|rate|rts|channel)$/
      OmfRc::Cmd.exec("#{IWCONFIG} #{uid} #{$+} #{value}")
    else
      super
    end
  end
end
