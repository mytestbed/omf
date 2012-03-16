require 'omf_rc/resource_proxy/interface'
require 'omf_rc/resource_proxy/wifi'

module OmfRc
  module ResourceProxy
    module Intel
      include OmfRc::ResourceProxy::Interface
      include OmfRc::ResourceProxy::Wifi

      IWCONFIG = 'iwconfig'
      IWPRIV = 'iwpriv'

      def configure_property(property, value)
        property.gsub!(/tx_power/, 'txpower')
        case property
        when /^type$/
          type_numeric = %w(a b g).index(value)
          type_numeric = type_numeric && type_numeric + 1
          `#{IWPRIV} #{uid} set_mode #{type_numeric}`
        when /^mode$/
          value.downcase!.gsub!(/adhoc/, 'ad-hoc')
          if value =~ /^(managed|master|monitor|ad-hoc)$/
            `#{IWCONFIG} #{uid} mode #{$+} essid dummy channel 1`
          end
        when /^(essid|frequency|txpower|rate|rts|channel)$/
          `#{IWCONFIG} #{uid} #{$+} #{value}`
        else
          super
        end
      end
    end
  end
end
