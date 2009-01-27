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
# = ethernet.rb
#
# == Description
#
# This file defines the class EthernetDevice, which is a sub-class of Device.
#
#
require 'omf_driver/device'

#
# This class represents an Ethernet device
#
class EthernetDevice < Device

  #
  # Create and set up a new EthernetDevice instance
  #
  def initialize(logicalName, deviceName)
    super(logicalName, deviceName)
  end

  #
  # Return the specific command required to configure a given property of this device.
  # When a property does not exist for this device, check if it does for its super-class.
  #
  # - prop = the property to configure
  # - value = the value to configure that property to
  #
  def getConfigCmd(prop, value)
    debug "looking for property '#{prop}' in ethernet"
    case prop
      when 'ip'
       return "/sbin/ifconfig #{@deviceName} #{value} netmask 255.255.0.0"
      when 'up'
       return "/sbin/ifconfig #{@deviceName} up"
      when 'down'
       return "/sbin/ifconfig #{@deviceName} down"
      when 'netmask'
        return "/sbin/ifconfig #{@deviceName} netmask #{value}"
      when 'arp'
        dash = (value == 'true') ? '' : '-'
        return "/sbin/ifconfig #{@deviceName} #{dash}arp"
      when 'forwarding'
        flag = (value == 'true') ? '1' : '0'
        return "echo #{flag} > /proc/sys/net/ipv4/conf/#{@deviceName}/forwarding"
      when 'gateway'
              return "route del default dev eth1; route add default gw #{value}; route add 224.10.10.6 dev eth1"
    end
    super
  end

end
