#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 WINLAB, Rutgers University, USA
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
# = intel.rb
#
# == Description
#
# This file defines the class IntelDevice which is a sub-class of WirelessDevice.
#
require 'omf_driver/wireless'

#
# This class represents an Intel device
#
class IntelDevice < WirelessDevice

  #
  # Create and set up a new IntelDevice instance
  #
  def initialize(logicalName, deviceName)
    super(logicalName, deviceName)
    @driver = 'ipw2200'
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
        return "iwpriv #{@deviceName} set_mode #{p}"

      when "mode"
        # 'value' defines mode of operation
        p = case
          when value == 'Managed' : 'managed'
          when value == 'managed' : 'managed'
          when value == 'Master' : 'master'
          when value == 'master' : 'master'
          when value == 'ad-hoc' : 'ad-hoc'
          when value == 'adhoc' : 'ad-hoc'
          when value == 'monitor' : 'monitor'
          else
            raise "Unknown mode '#{value}'. Should be 'managed', or 'ad-hoc'."
        end
        return "/sbin/iwconfig #{@deviceName} mode #{value} essid dummy channel 1"

      when "essid"
        @essid = value
        return "/sbin/iwconfig #{@deviceName} essid #{value}"

      when "frequency"
        return "/sbin/iwconfig #{@deviceName} freq #{value}"

      when "tx_power"
        return "/sbin/iwconfig #{@deviceName} txpower #{value}"

      when "rate"
        return "/sbin/iwconfig #{@deviceName} rate #{value}"

      when "rts"
        return "/sbin/iwconfig #{@deviceName} rts #{value}"

      when "channel"
        return "/sbin/iwconfig #{@deviceName} channel #{value}"

    end
    super
  end
end
