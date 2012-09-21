require 'hashie'
require 'cocaine'

module OmfRc::Util::Iw
  include OmfRc::ResourceProxyDSL
  include Cocaine
  include Hashie

  utility :ip

  # Parse iw help page and set up all configure methods available for iw command
  #
  CommandLine.new("iw", "help").run.chomp.gsub(/^\t/, '').split("\n").map {|v| v.match(/[phy|dev] <.+> set (\w+) .*/) && $1 }.compact.uniq.each do |p|
    configure p do |device, value|
      CommandLine.new("iw", "dev :dev set :property :value",
                      :dev => device.hrn,
                      :property => p,
                      :value => value).run
    end
  end

  # Parse iw link command output and return as a mash
  #
  request :link do |device|
    known_properties = Mash.new

    command = CommandLine.new("iw", "dev :dev link", :dev => device.hrn)

    command.run.chomp.gsub(/^\t/, '').split("\n").drop(1).each do |v|
      v.match(/^(.+):\W*(.+)$/).tap do |m|
        m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
      end
    end

    known_properties
  end

  # Parse iw info command output and return as a mash
  #
  request :info do |device|
    known_properties = Mash.new

    command = CommandLine.new("iw", "dev :dev info", :dev => device.hrn)

    command.run.chomp.split("\n").drop(1).each do |v|
      v.match(/^\W*(.+) (.+)$/).tap do |m|
        m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
      end
    end

    known_properties
  end

  # Initialise wpa related conf and pid location
  #
  work :init_wpa_conf_pid do |device|
    device.property.wpa_conf = "/tmp/wpa.#{device.hrn}.conf"
    device.property.wpa_pid = "/tmp/wpa.#{device.hrn}.pid"
  end

  # Initialise access point conf and pid location
  #
  work :init_ap_conf_pid do |device|
    device.property.ap_conf = "/tmp/hostapd.#{device.hrn}.conf"
    device.property.ap_pid = "/tmp/hostapd.#{device.hrn}.pid"
  end

  # Delete current interface, clean up
  #
  work :delele_interface do |device|
    CommandLine.new("iw", "dev :dev del", :dev => device.hrn).run
  end

  # Add interface to device
  #
  work :add_interface do |device, type|
    CommandLine.new("iw", "phy :phy interface add :dev type :type",
                    :phy => device.property.phy,
                    :dev => device.hrn,
                    :type => type.to_s).run
  end

  # Set up and run a hostapd instance
  #
  work :hostapd do |device|
    device.init_ap_conf_pid

    File.open(device.property.ap_conf, "w") do |f|
      f << "driver=nl80211\ninterface=#{device.hrn}\nssid=#{device.property.essid}\nchannel=#{device.property.channel}\n"
      f << "hw_mode=#{device.property.hw_mode}\n" if %w(a b g).include? device.property.hw_mode
      if device.property.hw_mode == 'n'
        if device.property.channel.to_i < 15
          f << "hw_mode=g\n"
        else device.property.channel.to_i > 15
          f << "hw_mode=a\n"
        end
        f << "wmm_enabled=1\nieee80211n=1\nht_capab=[HT20-]\n"
      end
    end

    CommandLine.new("hostapd", "-B -P :ap_pid :ap_conf",
                    :ap_pid => device.property.ap_pid,
                    :ap_conf => device.property.ap_conf).run
  end

  work :wpasup do |device|
    device.init_wpa_conf_pid

    File.open(device.property.wpa_conf, "w") do |f|
      f << "network={\n  ssid=\"#{device.property.essid}\"\n  scan_ssid=1\n  key_mgmt=NONE\n}"
    end
    CommandLine.new("wpa_supplicant", "-B -P :wpa_pid -i:dev -c:wpa_conf",
                    :wpa_pid => device.property.wpa_pid).run
  end

  work :validate_iw_properties do |device|
    raise ArgumentError, "Missing phyical device name" if device.property.phy.nil?

    unless %w(master managed adhoc monitor).include? device.property.mode
      raise ArgumentError, "Mode must be master, managed, adhoc, or monitor, got #{device.property.mode}"
    end

    case device.property.mode.to_sym
    when :master
      unless %w(a b g n).include? device.property.hw_mode
        raise ArgumentError, "Hardware mode must be a, b, g, or n, got #{device.property.hw_mode}"
      end
      %w(channel essid).each do |p|
        raise ArgumentError, "#{p} must not be nil" if device.property.send(p).nil?
      end
    when :managed
      %w(essid).each do |p|
        raise ArgumentError, "#{p} must not be nil" if device.property.send(p).nil?
      end
    when :adhoc
      %w(essid frequency).each do |p|
        raise ArgumentError, "#{p} must not be nil" if device.property.send(p).nil?
      end
    end
  end

  configure :mode do |device, value|
    # capture value hash and store internally
    device.property.update(value)

    device.validate_iw_properties

    device.delele_interface rescue logger.warn "Interface #{device.hrn} not found"

    case device.property.mode.to_sym
    when :master
      device.add_interface(:managed)
      device.hostapd
    when :managed
      device.add_interface(:managed)
      device.wpasup
    when :adhoc
      device.add_interface(:adhoc)
      # TODO this should go to ip
      device.interface_up
      CommandLine.new("iw", "dev :device ibss join :essid :frequency",
                      :device => device.hrn.to_s,
                      :essid => device.property.essid.to_s,
                      :frequency => device.property.frequency.to_s).run
    when :monitor
      device.add_interface(:monitor)
      # TODO this should go to ip
      device.interface_up
    end
  end
end
