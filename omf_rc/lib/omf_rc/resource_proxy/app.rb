module OmfRc::ResourceProxy::App
  PKGINFO = 'dpkg -l'
  PKGTOOL = 'apt-get'
  def request_property(property)
    case property
    when /^version$/
      OmfRc::Cmd.exec("#{PKGINFO} #{uid} | awk 'END { print $3 }'").match(/^[\d|\.|-]+$/) && $&
    else
      super
    end
  end

  def configure_property(property, value)
    case property
    when /^install$/
      OmfRc::Cmd.exec("#{PKGTOOL} #{$1} -y --reinstall --allow-unauthenticated -qq #{uid}")
    when /^(remove|purge)$/
      OmfRc::Cmd.exec("#{PKGTOOL} #{$1} -y -qq #{uid}")
    when /^exectue$/
      OmfRc::Cmd.exec(value)
    when /^terminate$/
      # TODO find the running process and send term signal
    when /^kill$/
      # TODO find the running process and send kill signals, value could be the type of KILL signal
    end
  end
end
