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
# = device.rb
#
# == Description
#
# This file defines the super class Device.
#

require 'omf-common/mobject'

#
# This class is the base class for all configurable devices, which are supported by the NA
#
class Device < MObject

  @@driverLoaded = Hash.new

  #
  # Unload device driver (i.e. kernel module)
  #
  def unload
    @@driverLoaded.each_key { |driver|
      reply = `/sbin/modprobe -r #{driver}`
      if ! $?.success?
        raise "Problems unloading module #{driver} -- #{reply}"
      end
      info "Unloaded #{driver} driver"
    }
    @@driverLoaded = Hash.new
  end

  attr_reader :deviceName, :logicalName

  #
  # Create and setup a new Device instance
  #
  # - logicalName = logical name for this device
  # - deviceName = name for this device
  #
  def initialize(logicalName, deviceName)
    @deviceName = deviceName
    @logicalName = logicalName
    @isActive = false
    @propertyList = Hash.new
  end

  #
  # Configure a property of this device
  #
  # - agent = Agent to inform about result
  # - prop = Property to configure
  # - value = Value to set property to
  #
  #def configure(agent, prop, value)
  def configure(prop, value)
    info "configure #{@logicalName}/#{prop} = #{value}"
    activate() # make sure that the device is actually loaded

    #if (value != nil) && (value[0] == '%'[0])
    #  # if value starts with "%" perform certain substitutions
    #  value = value[1..-1]  # strip off leading '%'
    #  value.sub!(/%x/, agent.x.to_s)
    #  value.sub!(/%y/, agent.y.to_s)
    #end

    path = "#{logicalName}/#{prop}"
    result = Hash.new
    begin
      cmd = getConfigCmd(prop, value)
      if cmd.nil?
        msg = "Some config parameters are missing, could not configure "+
              "'#{path}' for now, waiting for other parameters."
        result[:info] = msg
        result[:success] = true
        return result
      end
      debug "configure cmd: #{cmd}"
      reply = `#{cmd}`
      if $?.success?
        result[:success] = true
      else
        error("While configuring '#{prop}' with '#{value}' - Error: '#{reply}'")
        result[:success] = false
      end
      result[:info] = reply
      # HACK!!! Start
      # while we wait for a better device handling...
      result[:extra] = {:macaddr => get_property_value(:mac)} if prop == "ip"
      # HACK!!! End
    rescue => err
      error("While configuring '#{prop}' with '#{value}' \n\t#{err}")
      result[:success] = false
      result[:info] = err
    end
    return result
  end

  #
  # Return the specific command required to configure a given property of this device.
  # Raise an excepion ('Unknown property') if the property does not exist for this device.
  # This method does nothing in this Device super-class, it is meant to be overwritten by its sub-classes
  #
  # - prop = the property to configure
  # - value = the value to configure that property to
  #
  def getConfigCmd(prop, value)
    raise "Unknown property '#{prop}'"
  end

  #
  # Return true if device has been activated
  #
  # [Return] true/false
  #
  def active?
    return @isActive
  end

  #
  # Activate this device
  # This method just set our internal Activate state to true.
  # The real 'activation' tasks (e.g. loading a kernel module) will be done in the
  # subclasses, which will override this method.
  # This method may be called multiple times to ensure that device is UP
  #
  def activate()
    @isActive = true
  end

  # 
  # Execute some tasks after the 'activation' of this device
  # This method does nothing here, but may be overriden by the subclasses of Device.
  #
  def postActivate()
    return true
  end

  #
  # Called to clean up resources allocated so far. May reset all
  # configurations.
  #
  def deactivate()
    @isActive = false
  end

end

