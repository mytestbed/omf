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
# == Description
#
# This file defines the class WimaxcuDevice which is a sub-class of 
# WirelessDevice.
#
require 'omf-resctl/omf_driver/wimax'

#
# This class represents an Atheros device
#
class WimaxcuDevice < WimaxDevice

  def unload
    # don't unload the kernel module
    #super()
    debug "Disconnecting WiMAX #{@deviceName}"
    dconnect = `#{@wimaxcu} dconnect`
    @mode = @profile = @network = nil
  end
  
  #
  # Create and set up a new WimaxcuDevice instance
  #
  def initialize(logicalName, deviceName)
    super(logicalName, deviceName)
    @wimaxcu = '/usr/bin/wimaxcu'
    @mode = @profile = @network = nil
  end

  def buildCmd
    return nil if @mode.nil?
    cmd = nil
    case @mode
      when :profile
        return nil if @profile.nil?
        cmd = "#{@wimaxcu} ron ; #{@wimaxcu} dconnect; #{@wimaxcu} connect profile #{@profile};"
      when :network
        return nil if @network.nil?
        cmd = "#{@wimaxcu} ron ; #{@wimaxcu} dconnect; #{@wimaxcu} connect network #{@network};"
    else
      raise "Unknown mode '#{@mode}'. Should be 'profile', or 'network'"
    end
    return cmd
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
      when "profile"
		@mode = :profile
        @profile = value
        return buildCmd

      when "network"
        @mode = :network
        @network = value
        return buildCmd

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
