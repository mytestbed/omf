require 'hashie'

module OmfRc::Util::Iw
  include OmfRc::ResourceProxyDSL

  OmfCommon::Command.execute("iw help").chomp.gsub(/^\t/, '').split("\n").map {|v| v.match(/[phy|dev] <.+> set (\w+) .*/) && $1 }.compact.uniq.each do |p|
    configure p do |resource, value|
      OmfCommon::Command.execute("iw #{resource.hrn} set #{p} #{value}")
    end
  end

  request :link do |resource|
    known_properties = Hashie::Mash.new

    OmfCommon::Command.execute("iw #{resource.hrn} link").chomp.gsub(/^\t/, '').split("\n").drop(1).each do |v|
      v.match(/^(.+):\W*(.+)$/).tap do |m|
        m && known_properties[m[1].downcase.gsub(/\W+/, '_')] = m[2].gsub(/^\W+/, '')
      end
    end

    known_properties
  end

#def initialize(logicalName, deviceName)
#  super(logicalName, deviceName)
#  @driver = 'ath9k'
#  @iw = 'iw'
#  @hostapd = 'hostapd'
#  @wpasup = 'wpa_supplicant'
#  @apconf = "/tmp/hostapd.#{@deviceName}.conf"
#  @appid = "/tmp/hostapd.#{@deviceName}.pid"
#  @wpaconf = "/tmp/wpa.#{@deviceName}.conf"
#  @wpapid = "/tmp/wpa.#{@deviceName}.pid"
#  @type = @mode = @channel = @frequency = @essid = nil
#  @baseDevice = case
#    when @deviceName == 'wlan0' : 'phy0'
#    when @deviceName == 'wlan1' : 'phy1'
#  else
#    raise "Unknown device name '#{@deviceName}'."
#  end
#end
#
#def buildCmd
#  return nil if @mode.nil?
#  cmd = nil
#  case @mode
#    when :master
#      return nil if @type.nil? || @channel.nil? || @essid.nil?
#      clean = `#{@iw} dev #{@deviceName} del`
#      f = File.open(@apconf, "w")
#      f << "driver=nl80211\ninterface=#{@deviceName}\nssid=#{@essid}\nchannel=#{@channel}\n"
#      f << "hw_mode=#{@type}\n" if @type=='a' || @type=='b' || @type=='g'
#      f << "wmm_enabled=1\nieee80211n=1\nht_capab=[HT20-]\n" if @type=='n'
#      f << "hw_mode=g\n" if @type=='n' && @channel.to_i<15
#      f << "hw_mode=a\n" if @type=='n' && @channel.to_i>15
#      f.close
#      cmd = "#{@iw} phy #{@baseDevice} interface add #{@deviceName} type managed ; "+
#            "#{@hostapd} -B -P #{@appid} #{@apconf}"
#    when :managed
#      return nil if @essid.nil?
#      clean = `#{@iw} dev #{@deviceName} del`
#      f = File.open(@wpaconf, "w")
#      f << "network={\n  ssid=\"#{@essid}\"\n  scan_ssid=1\n  key_mgmt=NONE\n}"
#      f.close
#      cmd = "#{@iw} phy #{@baseDevice} interface add #{@deviceName} type managed ; "+
#            "#{@wpasup} -B -P #{@wpapid} -i#{@deviceName} -c#{@wpaconf}"
#    when :adhoc
#      return nil if @channel.nil? || @essid.nil?
#      clean = `#{@iw} dev #{@deviceName} del`
#      cmd = "#{@iw} phy #{@baseDevice} interface add #{@deviceName} type adhoc ; "+
#            "ifconfig #{deviceName} up ; "+
#            "#{@iw} dev #{@deviceName} ibss join #{@essid} #{FREQUENCY[@channel.to_i]}"
#    when :monitor
#      return nil if @channel.nil? || @essid.nil?
#      clean = `#{@iw} dev #{@deviceName} del`
#      cmd = "#{@iw} phy #{@baseDevice} interface add #{@deviceName} type monitor ; "+
#            "ifconfig #{deviceName} up ; "+
#            "#{@iw} dev #{@deviceName} set freq #{FREQUENCY[@channel.to_i]}"
#  else
#    raise "Unknown mode '#{value}'. Should be 'master', 'managed', "+
#          "'adhoc', or monitor."
#  end
#  return cmd
#end
#
##
## Return the specific command required to configure a given property of this
## device. When a property does not exist for this device, check if it does
## for its super-class.
##
## - prop = the property to configure
## - value = the value to configure that property to
##
#def getConfigCmd(prop, value)
#
#  @propertyList[prop.to_sym] = value
#  case prop
#    when 'type'
#      if value == 'a' || value == 'b' || value == 'g' || value == 'n'
#        @type = value
#      else
#        raise "Unknown type. Should be 'a', 'b', 'g', or 'n'"
#      end
#      return buildCmd
#
#    when "mode"
#      @mode = case
#        when value.downcase == 'master' : :master
#        when value.downcase == 'managed' : :managed
#        when value.downcase == 'ad-hoc' : :adhoc
#        when value.downcase == 'adhoc' : :adhoc
#        when value.downcase == 'monitor' : :monitor
#        else
#          raise "Unknown mode '#{value}'. Should be 'master', 'managed', "+
#                "'adhoc', or monitor."
#      end
#      return buildCmd
#
#    when "essid"
#      @essid = value
#      return buildCmd
#
#    when "rts"
#      return buildCmd
#
#   when "rate"
#      return buildCmd
#
#    when "frequency"
#      return buildCmd
#
#   when "channel"
#      @channel = value
#      return buildCmd
#
#   when "tx_power"
#      # Note: 'iw' support txpower setting only in latest version
#      # however current version shipped with natty (0.9.19) does not
#      # suppot that so for now we use 'iwconfig'
#      return "iwconfig #{@deviceName} txpower #{value}"
#
#  end
#  super
#end

end
