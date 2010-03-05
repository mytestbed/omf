#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2010 - WINLAB, Rutgers University, USA
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
# = aggmgrXmppCommunicator.rb
#
# == Description
#
#  This file defines the XMPP Communicator class used by the OMF Aggregate Manager.
#

require 'omf-common/xmppCommunicator'

class AggmgrXmppCommunicator < XmppCommunicator

  def self.init(opts)
    debug("Initializing AM XMPP Communicator object")
    super(opts)
    @@services = {}
  end

  def mount_proc(service_name, subservice_name, &block)
    service = @@services[service_name] || {}
    if subservice_name.nil?
      service[:descriptor] = block
    else
      subservices = service[:subservices] || {}
      subservices[subservice_name] = block
      service[:subservices] = subservices
    end
    @@services[service_name] = service
  end

  def process_command(command)
    service = @@services[command.cmdType]
    if service.nil?
      info("Unknown AM command #{command.cmdType}")
      debug("FIXME:  Need to send a reply to the sender notifying of bad command type")
    else
      if command.subservice.nil?
        @@services[service][:descriptor].call(self)
      else
        subservice = service[command.subservice]
        if subservice.nil?
          info("Unknown service call #{command.cmdType}, subservice #{command.subservice}")
        else
          subservice.call(self, command)
        end
      end
    end
  end
end
