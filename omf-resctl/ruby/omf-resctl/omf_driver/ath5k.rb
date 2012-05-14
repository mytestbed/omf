#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
# = ath5k.rb
#
# == Description
#
# This file defines the class Ath5kDevice which is a sub-class of 
# WirelessDevice.
#
require 'omf-resctl/omf_driver/wireless'

#
# This class represents an Ath5kDevice
#
class Ath5kDevice < WirelessDevice

  # Default version of the supported wireless tools
  DEFAULT_WIFI_TOOL_VERSION = 29

  #
  # Create and set up a new Ath5kDevice instance
  #
  def initialize(logicalName, deviceName)
    super(logicalName, deviceName)
    @driver = 'ath5k'
    @wlanconfig = '/sbin/wlanconfig'
    @iwconfig = '/sbin/iwconfig'
    @iwpriv = '/sbin/iwpriv'
  end

  #
  # Return the specific command required to configure a given property of this 
  # device. When a property does not exist for this device, check if it does 
  # for its super-class.
  #
  # - prop = the property to configure
  # - value = the value to configure that property to
  #
  def getConfigCmd(prop, value)

    @propertyList[prop.to_sym] = value
    case prop
      #when 'type'
      #  # 'value' defines type of operation
      #  type = case
      #    when value == 'a' : 1
      #    when value == 'b' : 2
      #    when value == 'g' : 3
      #    else
      #      raise "Unknown type. Should be 'a', 'b', or 'g'."
      #  end
      #  return "#{@iwpriv} #{@deviceName} mode #{type}"

      when "mode"
        if value.casecmp("master") == 0 || value.casecmp("managed") == 0 || value.casecmp("ad-hoc") == 0
          mode = value
        else
          raise "Unknown mode '#{value}'. Should be 'master', 'managed', or 'ad-hoc'."
        end
        # - Recent version of MADWIFI driver requires us to use 'wlanconfig' to
        # destroy and recreate the wireless device when changing its mode of
        # operation.
        # - Also when there are more than one wireless card on the node, we 
	# have to retrieve the 'base device' name of the card being used
        # By default, the madwifi config file on the node agents at NICTA 
	# assigns the device 'ath0' to the card 'wifi0', and 'ath1' to the 
	# card 'wifi1' (This is set in '/etc/init.d/atheros'. If you modified 
	# this config file on your on ORBIT deployment, the following lines 
	# must be changed accordingly)
        baseDevice = case
          when @deviceName == 'wlan0' : 'phy0'
          when @deviceName == 'wlan1' : 'phy1'
          else
            raise "Unknown device name '#{@deviceName}'."
        end
        
        return "#{@iwconfig} #{@deviceName} mode #{mode}"

      when "essid"
        @essid = value
        return "#{@iwconfig} #{@deviceName} essid #{value}"

      when "rts"
        return "#{@iwconfig} #{@deviceName} rts #{value}"

     when "rate"
        return "#{@iwconfig} #{@deviceName} rate #{value}"

      when "frequency"
        return "#{@iwconfig} #{@deviceName} freq #{value}"

     when "channel"
        return "#{@iwconfig} #{@deviceName} channel #{value}"

     when "tx_power"
        return "echo #{value} > /proc/sys/dev/#{@deviceName}/txpowlimit"

    end
    super
  end

  def get_property_value(prop)
    # Note: for now we are returning values set by a CONFIGURE command
    # when refactoring the device handling scheme, we may want to query
    # the system here to find out the real value of the property
    result = super(prop)
    result = @propertyList[prop] if !result
    return result 
  end

end
