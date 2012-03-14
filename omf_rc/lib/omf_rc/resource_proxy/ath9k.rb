require 'omf_rc/resource_proxy/interface'
require 'omf_rc/resource_proxy/wifi'
require 'erb'

module OmfRc::ResourceProxy
  module Ath9k
    include OmfRc::ResourceProxy::Interface
    include OmfRc::ResourceProxy::Wifi

    IWCONFIG = 'iwconfig'
    IW = 'iw'
    HOSTAPD = 'hostapd'
    WPASUP = 'wpa_supplicant'

    APCONF = %w(hostapd .conf)
    WPACONf = %w(wpa .conf)

    APPID = %w(hostapd .pid)
    WPAPID = %w(wpa .pid)

    FREQUENCY = {
      1 => '2412',
      2 => '2417',
      3 => '2422',
      4 => '2427',
      5 => '2432',
      6 => '2437',
      7 => '2442',
      8 => '2447',
      9 => '2452',
      10 => '2457',
      11 => '2462',
      12 => '2467',
      13 => '2472',
      14 => '2484',
      36 => '5180',
      40 => '5200',
      44 => '5220',
      48 => '5240',
      52 => '5260',
      56 => '5280',
      60 => '5300',
      64 => '5320',
      100 => '5500',
      104 => '5520',
      108 => '5540',
      112 => '5560',
      116 => '5580',
      120 => '5600',
      124 => '5620',
      128 => '5640',
      132 => '5660',
      136 => '5680',
      140 => '5700',
      149 => '5745',
      153 => '5765',
      157 => '5785',
      161 => '5805',
      165 => '5825'
    }

    def configure_property(property, value)
      wifi_configure = Hashie::Mashie.new
      base_device = uid.gsub(/wlan/, 'phy')
      %(mode essid rts rate frequency tx_power).each do |p|
        wifi_configure.send("#{p}=", request_proerpty(p)
      end

      case property
      when /^(type|mode|essid|rts|rate|frequency|channel)$/
        wifi_configure.send("#{$+}=", value)
        case wifi_configure.mode.downcase!
        when /^master$/
          `#{IW} dev #{uid} del`
          ap_conf = render_template(APCONF, bindling)
          ap_pid = Tempfile.new(APPID)
          `#{IW} phy #{base_device} interface add #{uid} type managed`
          `#{HOSTAPD} -B -P #{ap_pid.path} #{ap_conf.path}`
        when /^managed$/
          `#{IW} dev #{uid} del`
          wpa_conf = render_template(WPACONf, binding)
          wpa_pid = Tempfile.new(WPAPID)
          `#{IW} phy #{base_device} interface add #{uid} type managed`
          `#{WPASUP} -B -P #{wpa_pid.path} -i#{uid} -c#{wpa_conf.path}`
        when /^adhoc$/
          `#{IW} dev #{uid} del`
          `#{IW} phy #{base_device} interface add #{uid} type adhoc`
          `#{IFCONFIG} #{uid} up`
          `#{IW} dev #{uid} ibss join #{wifi_configure.essid} #{FREQUENCY[wifi_configure.channel]}`
        when /^monitor$/
          `#{IW} dev #{uid} del`
          `#{IW} phy #{base_device} interface add #{uid} type monitor`
          `#{IFCONFIG} #{uid} up`
          `#{IW} dev #{uid} set freq #{FREQUENCY[wifi_configure.channel]}`
        end
      when /^tx_power$/
        `#{IWCONFIG} #{uid} txpower #{value}`
      end
      super
    end

    private

    def render_template(template_name, binding)
      Tempfile.new(template_name) do |f|
        f.write ERB.new(File.read("./template/#{template_name.join}")).result(bindling)
      end
    end
  end
end
