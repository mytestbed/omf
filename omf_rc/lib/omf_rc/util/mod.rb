module OmfRc::Util::Mod

  LSMOD_CMD = 'lsmod'
  MODPROBE_CMD = 'modprobe'

  def request_property(property)
    case property
    when /^(mod|driver)_(.+)$/
      OmfRc::Cmd.exec(LSMOD).match(/^#{$+}( )+/) ? true : false
    else
      super
    end
  end

  def configure_property(property, value)
    case property
    when /^(mod|driver)_(.+)$/
      OmfRc::Cmd.exec("#{MODPROBE} #{$+}")
    else
      super
    end
  end
end
