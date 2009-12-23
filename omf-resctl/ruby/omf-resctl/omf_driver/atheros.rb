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
# = atheros.rb
#
# == Description
#
# This file defines the class AtherosDevice which is a sub-class of WirelessDevice.
#
require 'omf-resctl/omf_driver/wireless'

#
# This class represents an Atheros device
#
class AtherosDevice < WirelessDevice

  # Default version of the supported wireless tools
  DEFAULT_WIFI_TOOL_VERSION = 29

  #
  # Create and set up a new AtherosDevice instance
  #
  def initialize(logicalName, deviceName)
    super(logicalName, deviceName)
    @driver = 'ath_pci'
    # Find the paths to the required tools
    # In some instances (e.g. winlab's baseline image as of Dec 09) these
    # tools are not in the default path at boot time.
    @wlanconfig = `find / -name  wlanconfig`.chomp!
    @iwconfig = `find / -name  iwconfig`.chomp!
    @iwpriv = `find / -name  iwpriv`.chomp!
    @toolVersion = getToolVersion
  end

  #
  # Return the version of the madwifi tools
  # 
  # [Return] the versions of the madwifi tools
  #
  def getToolVersion()
    cmd = "#{@wlanconfig} --version | head -n 1 | awk '{print $4}'"
    version = `#{cmd}`
    if !($?.success?) || (version.to_i == 0)
      debug "Could not determine Wireless Tool version! Default to version: #{DEFAULT_WIFI_TOOL_VERSION}"
      return DEFAULT_WIFI_TOOL_VERSION
    else
      debug "Wireless Tool version: #{version.to_i}"
      return version.to_i
    end
  end

  #
  # Return the specific command required to configure a given property of this device.
  # When a property does not exist for this device, check if it does for its super-class.
  #
  # - prop = the property to configure
  # - value = the value to configure that property to
  #
  def getConfigCmd(prop, value)

    case prop
      when 'type'
        # 'value' defines type of operation
        p = case
          when value == 'a' : 1
          when value == 'b' : 2
          when value == 'g' : 3
          else
            raise "Unknown type. Should be 'a', 'b', or 'g'."
        end
        return "#{@iwpriv} #{@deviceName} mode #{p}"

      when "mode"
        p = case
          when value == 'master' : 'ap'
          when value == 'Master' : 'ap'
          when value == 'managed' : 'sta'
          when value == 'Managed' : 'sta'
          when value == 'ad-hoc' : 'adhoc'
          when value == 'Ad-Hoc' : 'adhoc'
          when value == 'adhoc' : 'adhoc'
          when value == 'AdHoc' : 'adhoc'
          when value == 'monitor' : 'monitor'
          when value == 'Monitor' : 'monitor'
          else
            raise "Unknown mode '#{value}'. Should be 'master', 'managed', or 'adhoc'."
        end
        # - Recent version of MADWIFI driver requires us to use 'wlanconfig' to
        # destroy and recreate the wireless device when changing its mode of
        # operation.
        # - Also when there are more than one wireless card on the node, we have to 
        # retrieve the 'base device' name of the card being used
        # By default, the madwifi config file on the node agents at NICTA assigns 
        # the device 'ath0' to the card 'wifi0', and 'ath1' to the card 'wifi1'
        # (This is set in '/etc/init.d/atheros'. If you modified this config file on 
        # your on ORBIT deployment, the following lines must be changed accordingly)
        baseDevice = case
          when @deviceName == 'ath0' : 'wifi0'
          when @deviceName == 'ath1' : 'wifi1'
          else
            raise "Unknown device name '#{@deviceName}'."
        end

        if (@toolVersion < DEFAULT_WIFI_TOOL_VERSION)
          # Backward compatibility: NodeAgent will run with previous MADWIFI drivers
          return "#{@iwconfig} #{@deviceName} mode #{value}"
        else
          return "#{@wlanconfig} #{@deviceName} destroy ; #{@wlanconfig} #{@deviceName} create wlandev #{baseDevice} wlanmode #{p}"
        end

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

end
