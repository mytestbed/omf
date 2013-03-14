require 'hashie'
require 'cocaine'
require 'tempfile'

module OmfRc::Util::Wpa
  include OmfRc::ResourceProxyDSL
  include Cocaine

  # Initialise wpa related conf and pid location
  #
  work :init_wpa_conf_pid do |device|
    device.property.wpa_conf = Tempfile.new(["wpa.#{device.property.if_name}", ".conf"]).path
    device.property.wpa_pid = Tempfile.new(["wpa.#{device.property.if_name}", ".pid"]).path
  end

  work :wpasup do |device|
    device.init_wpa_conf_pid

    File.open(device.property.wpa_conf, "w") do |f|
      f << "network={\n  ssid=\"#{device.property.essid}\"\n  scan_ssid=1\n  key_mgmt=NONE\n}"
    end
    CommandLine.new("wpa_supplicant", "-B -P :wpa_pid -i:dev -c:wpa_conf",
                    :dev => device.property.if_name,
                    :wpa_conf => device.property.wpa_conf,
                    :wpa_pid => device.property.wpa_pid).run
  end

  work :stop_wpa do |device|
    begin
      File.open(device.property.wpa_pid,'r') do |f|
        logger.debug "Stopping wpa supplicant at PID: #{device.property.wpa_pid}"
        CommandLine.new("kill", "-9 :pid", :pid => f.read.chomp).run
      end

      CommandLine.new("rm", "-f :wpa_pid :wpa_conf",
                      :wpa_pid => device.property.wpa_pid,
                      :wpa_conf => device.property.wpa_conf).run
    rescue => e
      logger.warn "Failed to clean wpa supplicant and its related files '#{device.property.wpa_pid}' and '#{device.property.wpa_conf}'!"
      logger.warn e.message
    end
  end
end
