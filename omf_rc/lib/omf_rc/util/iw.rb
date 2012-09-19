require 'hashie'
require 'cocaine'

module OmfRc::Util::Iw
  include OmfRc::ResourceProxyDSL
  include Cocaine
  include Hashie

  hook :before_ready do |device|
    device.property.wpa_conf = "/tmp/wpa.#{device.hrn}.conf"
    device.property.wpa_pid = "/tmp/wpa.#{device.hrn}.pid"
    device.property.ap_conf
    device.property.ap_pid
  end

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

    command = CommandLine.new("iw", ":dev link", :dev => device.hrn)

    command.run.chomp.gsub(/^\t/, '').split("\n").drop(1).each do |v|
      v.match(/^(.+):\W*(.+)$/).tap do |m|
        m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
      end
    end

    known_properties
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
                    :phy => device.hrn.gsub(/wlan/, 'phy'),
                    :dev => device.hrn,
                    :type => type).run
  end

  # Set up and run a hostapd instance
  #
  work :hostapd do |device|
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
    File.open(device.property.wpa_conf, "w") do |f|
      f << "network={\n  ssid=\"#{device.property.essid}\"\n  scan_ssid=1\n  key_mgmt=NONE\n}"
    end
    CommandLine.new("wpa_supplicant", "-B -P :wpa_pid -i:dev -c:wpa_conf",
                    :wpa_pid => device.property.wpa_pid)
  end

  configure :mode do |device, value|
    # capture value hash and store internally
    device.property.update(value)

    case device.property.mode.to_sym
    when :master
      delele_interface
      add_interface(:managed)
      hostapd
    when :managed
      delele_interface
      add_interface(:managed)
      wpasup
    when :adhoc
      delele_interface
      add_interface(:adhoc)
      # TODO this should go to ip
      CommandLine.new("ip", "link set :dev up", :dev => device.hrn).run

      CommandLine.new("iw", "dev :device ibss join :essid :frequency",
                      :device => device.hrn,
                      :essid => device.property.essid,
                      :frequency => device.property.frequency).run
    when :monitor
      delele_interface
      add_interface(:monitor)
      # TODO this should go to ip
      CommandLine.new("ip", "link set :dev up", :dev => device.hrn).run
    end
  end
end
