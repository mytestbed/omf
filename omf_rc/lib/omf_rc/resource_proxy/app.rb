module OmfRc::ResourceProxy::App
  APPINFO = 'dpkg -l'
  APPTOOL = 'apt'
  def request_property(property)
    case property
    when /^version$/
      OmfRc::Cmd.exec("#{APPINFO} #{uid} | awk 'END { print $3 }'").match(/^[\d|\.|-]+$/) && $&
    else
      super
    end
  end

  def configure_property(property, value)
    case property
    when /^install$/
      OmfRc::Cmd.exec("LANGUAGE='C' LANG='C' LC_ALL='C' DEBIAN_FRONTEND='noninteractive' #{PKGTOOL} install --reinstall --allow-unauthenticated -qq #{uid}")
    when /^remove$/
      operation = value == 'purge' ? 'purge' : 'remove'
      OmfRc::Cmd.exec("LANGUAGE='C' LANG='C' LC_ALL='C' DEBIAN_FRONTEND='noninteractive' #{PKGTOOL} #{operation} --allow-unauthenticated -qq #{uid}")
    when /^exectue$/
      # TODO build the actual command and execute
    when /^kill$/
      # TODO find the running process and send kill signals, value could be the type of KILL signal
    end
  end
end
