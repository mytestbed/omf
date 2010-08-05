#
# Copyright (c) 2010 National ICT Australia (NICTA), Australia
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
# = servicerMounter.rb
#
# == Description
#
# This file defines the ServiceMounter class which is responsible for mounting
# Aggregate Manager services on a network transport server (such as HTTP or XMPP).
#


require 'omf-common/mobject'
require 'omf-aggmgr/ogs/server'

class ServiceMounter < MObject
  @@servers = {}

  def self.init(params)
    @@servers[:http] = AggmgrServer.create_server(:http, params)
    @@servers[:xmpp] = AggmgrServer.create_server(:xmpp, params)
  end

  def self.start_services
    MObject.debug(:gridservices, "Starting AM servers")

    @@servers.each_pair { |type,server|
      MObject.debug(:gridservices, "Starting thread for '#{type}' server")
      Thread.new {server.start}
    }

    @@should_stop = false
    while @@should_stop == false
      sleep 3
      if @@should_stop
        @@servers.values.each { |server| server.stop }
      end
    end
  end

  def self.stop_services
    MObject.debug(:gridservices, "Stopping AM servers")
    @@should_stop = true
  end

  def self.mount(service_class, transport = nil)
    if transport.nil? then
      # Mount service on all transports
      @@servers.values.each { |server| server.mount(service_class) }
    else
      @@servers[transport].mount(service_class)
    end
  end

  def self.server(type)
    @@servers[type].server
  end
end




