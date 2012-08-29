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
require 'omf-resctl/omf_driver/device'

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
       return "ifconfig #{@deviceName} #{value} netmask 255.255.0.0"
      when 'up'
       return "ifconfig #{@deviceName} up"
      when 'down'
       return "ifconfig #{@deviceName} down"
      when 'netmask'
        return "ifconfig #{@deviceName} netmask #{value}"
      when 'mtu'
        return "ifconfig #{@deviceName} mtu #{value}"
      when 'mac'
        return "ifconfig #{@deviceName} hw ether #{value}"
      when 'arp'
        dash = (value == 'true') ? '' : '-'
        return "ifconfig #{@deviceName} #{dash}arp"
      when 'forwarding'
        flag = (value == 'true') ? '1' : '0'
        return "echo #{flag} > /proc/sys/net/ipv4/conf/#{@deviceName}/forwarding"
      when 'route'
        return getCmdForRoute(value)
      when 'filter'
        return getCmdForFilter(value)
      when 'gateway'
              return "route del default dev eth1; route add default gw #{value}; route add 224.10.10.6 dev eth1"
    end
    super
  end

  #
  # Return the specific command required to configure a 'route' property of this device.
  # This command is based on the Linux 'route' command
  #
  # - value = the value to configure the 'route' property to
  #
  def getCmdForRoute(value)
    param = eval(value)
    operation = param[:op]
    if operation == 'add' || operation == 'del'
      routeCMD = "route #{operation} -net #{param[:net]} "
      param.each_pair { |k,v|
        case k
          when :gw
            routeCMD << "gw #{v} "
          when :mask
            routeCMD << "netmask #{v} "
        end
      }
      routeCMD << "dev #{@deviceName}"
    else
      MObject.error "Route configuration - unknown operation: '#{operation}'" 
      routeCMD = "route xxx" # This will raise an error in the calling method
    end
    return routeCMD
  end

  #
  # Return the specific command required to configure a 'filter' property of this device.
  # This command is based on the Linux 'iptables' command
  #
  # - value = the value to configure the 'filter' property to
  #
  def getCmdForFilter(value)
    param = eval(value)
    operation = param[:op]
    filterCMD = "iptables "
    param.each {|k,v|
    }
    case operation
      when 'add' 
        filterCMD << "-A "
      when 'del'
        filterCMD << "-D "
      when 'clear'
        return filterCMD << "-F"
      else
        MObject.error "Filter configuration - unknown operation: '#{operation}'" 
        return filterCMD
    end
    filterCMD << "#{param[:chain].upcase} -i #{@deviceName} "
    case param[:proto]
      when 'tcp', 'udp'
        filterCMD << "-p #{param[:proto]} "
        param.each { |k,v|
          case k
            when :src
              filterCMD << "-s #{v} "
            when :dst
              filterCMD << "-d #{v} "
            when :sport
              filterCMD << "--sport #{v} "
            when :dport
              filterCMD << "--dport #{v} "
          end
        }
      when 'mac'
        filterCMD << "-m mac --mac-source #{param[:src]} "
    end
    filterCMD << "-j #{param[:target].upcase}"
    return filterCMD
  end

  def get_property_value(prop)
    return nil if !RUBY_PLATFORM.include?('linux')
    case prop
    when :mac
      match = /[.\da-fA-F]+\:[.\da-fA-F]+\:[.\da-fA-F]+\:[.\da-fA-F]+\:[.\da-fA-F]+\:[.\da-fA-F]+/
      lines = IO.popen("ifconfig #{@deviceName}", "r").readlines
      return lines[0][match] if (lines.length >= 2)
      return nil
    when :ip
      match = /[.\d]+\.[.\d]+\.[.\d]+\.[.\d]+/
      lines = IO.popen("ifconfig #{@deviceName}", "r").readlines
      return lines[1][match] if (lines.length >= 2)
      return nil
    else
      return nil
    end
  end


end
