# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'hashie'
require 'cocaine'
require 'tempfile'

# Manage Hostapd instances
module OmfRc::Util::Hostapd
  include OmfRc::ResourceProxyDSL
  include Cocaine
  # @!macro extend_dsl

  # @!macro group_work
  # Initialise access point conf and pid location
  #
  # @!method init_ap_conf_pid
  work :init_ap_conf_pid do |device|
    device.property.ap_conf = Tempfile.new(["hostapd.#{device.property.if_name}", ".conf"]).path
    device.property.ap_pid = Tempfile.new(["hostapd.#{device.property.if_name}", ".pid"]).path
  end

  # Set up and run a hostapd instance
  #
  # @!method hostapd
  work :hostapd do |device|
    device.init_ap_conf_pid

    File.open(device.property.ap_conf, "w") do |f|
      f << "driver=nl80211\ninterface=#{device.property.if_name}\nssid=#{device.property.essid}\nchannel=#{device.property.channel}\n"
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

  # @!method stop_hostapd
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
  # @!endgroup
end
