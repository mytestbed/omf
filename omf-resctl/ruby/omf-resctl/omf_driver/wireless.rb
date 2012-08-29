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
# = wireless.rb
#
# == Description
#
# This file defines the class WirelessDevice, which is a sub-class of EthernetDevice.
#
#
require 'omf-resctl/omf_driver/ethernet'

#
# This class represents a generic wireless device
#
class WirelessDevice < EthernetDevice

  # Interval in seconds beween checks of device
  # state.
  STATE_TRACE_INTERVAL = 10

  attr_reader :driver, :essid

  #
  # Create and set up a new WirelessDevice instance
  #
  def initialize(logicalName, deviceName)
    super(logicalName, deviceName)
    @essid = "ORBIT"

    # monitor state
    Thread.new() {
      while true
        begin
          if active?
            checkStatus
          else
            resetState
          end
        rescue
        end
        sleep STATE_TRACE_INTERVAL
      end
    }
  end

  # know cell id
  attr_reader :cellID

  #
  # Return the status of this Wireless Device.
  # At the moment we are only concerned about the CELL ID state of this device.
  #
  # [Return] the Cell ID of this Device
  #
  def checkStatus
    reply = `iwconfig #{deviceName}`
    if ! $?.success?
      warn "Problems running iwconfig -- #{reply}"
      return
    end
    if (m = reply.match(/(Access Point|Cell): ([^ ]+)/))
      id = m[2]
      if (@cellID != id)
        @cellID = id
        info("New Cell ID: #{@cellID}")
        NodeAgent.instance.onDevEvent(:CELL_ID, logicalName, @cellID)
      end
    end
  end

  #
  # Called whenever the agent is being reset. Right now
  # it's only detected inside the check status thread. FIX ME!
  #
  def resetState
    @cellID = nil
  end

  #
  # Return true if device has been activated and loaded
  #
  # [Return] true/false
  #  
  def active?
    return @isActive && loaded?
  end

  #
  # Return true if device is loaded
  #
  # [Return] true/false
  #
  def loaded?
    @@driverLoaded.has_key?(driver)
  end

  #
  # Activate this device
  # In this case, this will loading the kernel module to handle this type of device
  # This method may be called multiple times to ensure that device is UP
  #
  def activate()
    debug "activate: #{deviceName} #{driver} #{loaded?}"
    super()
    if (! loaded?)
      reply = `modprobe #{driver}`
      if ! $?.success?
        error "Problems loading module '#{driver}' -- '#{reply}'"
        raise "Problems loading module #{driver} -- #{reply}"
      end
      info("Loaded #{driver} driver")
      @@driverLoaded[driver] = true
    end
  end

end
