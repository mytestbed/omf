# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

require 'hashie'
require 'cocaine'
require 'tempfile'

# Manage WPA instances
module OmfRc::Util::Wpa
  include OmfRc::ResourceProxyDSL
  include Cocaine
  # @!macro extend_dsl

  # @!macro group_work
  # Initialise wpa related conf and pid location
  #
  # @!method init_wpa_conf_pid
  work :init_wpa_conf_pid do |device|
    device.property.wpa_conf = Tempfile.new(["wpa.#{device.property.if_name}", ".conf"]).path
    device.property.wpa_pid = Tempfile.new(["wpa.#{device.property.if_name}", ".pid"]).path
  end

  # @!method wpasup
  work :wpasup do |device|
    device.init_wpa_conf_pid

    File.open(device.property.wpa_conf, "w") do |f|
      f << "network={\n  ssid=\"#{device.property.essid}\"\n  scan_ssid=1\n  key_mgmt=NONE\n}"
    end
    c=CommandLine.new("wpa_supplicant", "-B -P :wpa_pid -i:dev -c:wpa_conf")
    c.run({         :dev => device.property.if_name,
                    :wpa_conf => device.property.wpa_conf,
                    :wpa_pid => device.property.wpa_pid  })
  end

  # @!method stop_wpa
  work :stop_wpa do |device|
    begin
      File.open(device.property.wpa_pid,'r') do |f|
        info "Stopping wpa supplicant at PID: #{device.property.wpa_pid}"
        c1=CommandLine.new("kill", "-9 :pid")
        c1.run({ :pid => f.read.chomp })
      end

	  c2=CommandLine.new("rm", "-f :wpa_pid :wpa_conf")
      c2.run({         :wpa_pid => device.property.wpa_pid,
                      :wpa_conf => device.property.wpa_conf  })
    rescue => e
      logger.warn "Failed to clean wpa supplicant and its related files '#{device.property.wpa_pid}' and '#{device.property.wpa_conf}'!"
      logger.warn e.message
    end
  end
  # @!endgroup
end
