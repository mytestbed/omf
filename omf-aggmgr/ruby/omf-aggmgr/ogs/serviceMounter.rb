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
  @@thread = nil

  def self.init(params)
    if params[:http]
      @@servers[:http] = AggmgrServer.create_server(:http, params)
    end
    if params[:xmpp]
      @@servers[:xmpp] = AggmgrServer.create_server(:xmpp, params)
    end
  end

  def self.start_services
    MObject.debug(:gridservices, "Starting AM servers")

    @@servers.each_pair { |type,server|
      MObject.debug(:gridservices, "Starting thread for '#{type}' server")
      Thread.new {server.start}
    }

    # Stop the current thread and wait for stop_services to be
    # called and wake us up
    @@thread = Thread.current
    Thread.stop

    MObject.info(:gridservices, "Stopping AM servers")

    # Issue stop commands to individual servers
    @@servers.values.each { |server| server.stop }

    MObject.info(:gridservices, "Waiting for all servers to stop")

    all_stopped = false
    count = 0
    while not all_stopped
      stopped = []
      @@servers.values.each { |server|
        if server.stopped?
          stopped << server
        end
      }
      sleep 1
      if stopped.length == @@servers.length
        all_stopped = true
      else
        MObject.info(:gridservices, "... still waiting")
        count += 1
      end

      if not all_stopped and count > 5
        break
      end
    end
    MObject.info(:gridservices, "... done.")
  end

  def self.stop_services
    MObject.debug(:gridservices, "Stopping AM servers")
    @@thread.run if not @@thread.nil?
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




