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
# = aironet.rb
#
# == Description
#
# This file defines the class AironetDevice which is a sub-class of WirelessDevice.
#
require 'omf-resctl/omf_driver/wireless'

#
# This class represents an Cisco Aironet device
#
class AironetDevice < WirelessDevice


  attr_reader :essid

  #
  # Create and set up a new AironetDevice instance
  #
  def initialize(logicalName, deviceName)
    super(logicalName, deviceName)
    @driver = 'airo_pci'
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
      when "mode"
        return "iwconfig #{@deviceName} mode #{value} essid #{@essid}"

#      when /.*:status/
#        return "ifconfig #{@deviceName} #{value}"

      when "essid"
        @essid = value
        return "iwconfig #{@deviceName} essid #{value}"

      when "channel"
        channel = value.to_i
        if (channel < 1 || channel > 11)
          raise "Unsupported channel '#{channel}'. Need to be between 1 and 11."
        end
        return "echo 'Channel: #{value}' >> /proc/driver/aironet/#{@deviceName}/Config"

      when "tx_power"
        power = value.to_i
        if (! [1, 5, 20, 30, 50, 100].include?(power))
          raise "Unsupported power level '#{power}'. Valid levels are 1, 5, 20, 30, 50, 100."
        end
        return "echo 'XmitPower: #{value}' >> /proc/driver/aironet/#{@deviceName}/Config"

      when "bitrate"
        r = value.to_i
        br = case
          when r == 1 : 2
          when r == 2 : 4
          when r == 5.5 : 11
          when r == 11 : 22
          else
            raise "Unknown bitrate #{value}. Valid rates are 1, 2, 5.5, and 11."
        end
        return "echo 'DataRates: #{br} 0 0 0 0' >> /proc/driver/aironet/#{@deviceName}/Config"

      when "frag_threshold"
        # 'value' is number of bytes after which payload is fragmented
        return "echo 'FragThreshold: #{value}' >> /proc/driver/aironet/#{@deviceName}/Config"

      when "retries"
        # 'value' is number of retries. '0' disables them
        s = "echo 'LongRetryLimit: #{value}' >> /proc/driver/aironet/#{@deviceName}/Config;"
        return s + "echo 'LongRetryLimit: #{value}' >> /proc/driver/aironet/#{@deviceName}/Config"

      when "rts_threshold"
        # 'value' is number of bytes until which there is no RTS/CTS exchange So, to
        # enable RTS/CTS for ALL packets the value should be set to 0. To disable it,
        # it should be set to max MTU = 2312 bytes
        return "echo 'RTSThreshold: #{value}' >> /proc/driver/aironet/#{@deviceName}/Config"
    end
    super
  end

  #
  # Called multiple times to ensure that device is up
  #
  def activate()
    if (! @loaded)
      reply = `modprobe airo_pci`
      if ! $?.success?
        raise "Problems loading Aironet module -- #{reply}"
      end
      @loaded = true
      @@driverLoaded = true
    end
  end


end
