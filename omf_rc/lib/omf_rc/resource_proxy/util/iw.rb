module OmfRc::ResourceProxy::Util::Iw

  IW_CMD = "iw"

  def configure_property(property, value)
    property.gsub!(/tx_power/, 'txpower')
    case property
    when /^essid$/
      OmfRc::Cmd.exec("#{IW_CMD} #{uid} connect #{value}")
    when /^(freq|txpower|rts|channel)$/
      OmfRc::Cmd.exec("#{IW_CMD} #{uid} set #{$+} #{value}")
    else
      super
    end
  end

  def request_property(property)
    case property
    when /^cell_id$/
      OmfRc::Cmd.exec("#{IW_CMD} #{uid} link").match(/Connected to: ([^ ]+)/) && $+
    when /^mode$/
      OmfRc::Cmd.exec("#{IW_CMD} #{uid} info").match(/type (\S+)/) && $+
    when /^essid|ssid$/
      OmfRc::Cmd.exec("#{IW_CMD} #{uid} link").match(/SSID: (\S+)/) && $+
    when /^rate|bitrate$/
      OmfRc::Cmd.exec("#{IW_CMD} #{uid} link").match(/bitrate: (\S+)/) && $+
    when /^frequency|freq$/
      OmfRc::Cmd.exec("#{IW_CMD} #{uid} link").match(/freq: (\S+)/) && $+
    when /^signal$/
      OmfRc::Cmd.exec("#{IW_CMD} #{uid} link").match(/signal: (\S+)/) && $+
    else
      super
    end
  end
end

