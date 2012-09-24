require 'hashie'
require 'cocaine'

module OmfRc::Util::Hostapd
  include OmfRc::ResourceProxyDSL
  include Cocaine

  # Initialise access point conf and pid location
  #
  work :init_ap_conf_pid do |device|
    device.property.ap_conf = "/tmp/hostapd.#{device.hrn}.conf"
    device.property.ap_pid = "/tmp/hostapd.#{device.hrn}.pid"
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

  work :stop_hostapd do |device|
    begin
      File.open(device.property.ap_pid,'r') do |f|
        logger.debug "Stopping hostapd process at PID: #{device.property.ap_pid}"
        CommandLine.new("kill", "-9 :pid", :pid => f.read.chomp).run
      end

      CommandLine.new("rm", "-f :ap_pid :ap_conf",
                      :ap_pid => device.property.ap_pid,
                      :ap_conf => device.property.ap_conf).run
    rescue => e
      logger.warn "Failed to clean hostapd and its related files '#{device.property.ap_pid}' and '#{device.property.ap_conf}'!"
      logger.warn e.message
    end
  end
end
