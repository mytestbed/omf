module OmfRc::ResourceProxy
  module Wifi
    LSMOD = 'lsmod'
    MODPROBE = 'modprobe'
    IWCONFIG = 'iwconfig'

    def request_property(property)
      # FIXME how to get type and channel info
      case property
      when /^driver_(.+)$/
        `#{LSMOD}`.match(/^#{$+}( )+/) ? true : false
      when /^cell_id$/
        `#{IWCONFIG} #{uid}`.match(/(Access Point|Cell): ([^ ]+)/) && $+
      when /^mode$/
        `#{IWCONFIG} #{uid}`.match(/Mode:(\S+)/) && $+
      when /^essid$/
        `#{IWCONFIG} #{uid}`.match(/ESSID:(\S+)/) && $+
      when /^rts$/
        `#{IWCONFIG} #{uid}`.match(/RTS (\S+)/) && $+
      when /^rate$/
        `#{IWCONFIG} #{uid}`.match(/Rate=(\S+)/) && $+
      when /^frequency$/
        `#{IWCONFIG} #{uid}`.match(/Frequency:(\S+)/) && $+
      when /^tx_power$/
        `#{IWCONFIG} #{uid}`.match(/Tx-Power=(\S+)/) && $+
      else
        super
      end
    end

    def configure_property(property, value)
      case property
      when /^driver_(.+)$/
        `#{MODPROBE} #{$+}`
      else
        super
      end
    end
  end
end
