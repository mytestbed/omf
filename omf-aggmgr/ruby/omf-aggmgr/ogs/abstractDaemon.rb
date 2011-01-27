#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 - WINLAB, Rutgers University, USA
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
# = abstractDaemon.rb
#
# == Description
#
# This file defines the AbstractDaemon class.
#
require 'omf-aggmgr/ogs/timer'

#
# This class defines the general Daemon class. This class is used by all the
# Services that calls an external daemon software to perform their required tasks.
# The AbstractDameon class serves as the interface between the GridServices of
# OMF and the external daemon software.
# This class is meant to be sub-classed for a particular type of Daemon required by a Service.
# This class not only represent a single Daemon instance, but it also provides a class-wide
# array of Daemon instances currently associated with a Service.
#
class AbstractDaemon < MObject

  # Max. number of active daemons allowed
  DEF_MAX_DAEMONS = 10
  # Time out daemon if nobody requested it within TIMEOUT sec
  DEF_TIMEOUT = 10000

  # Using ports starting at ...
  DEF_START_PORT = 7000

  @@inst = Hash.new
  @@globalConfig = Hash.new

  #
  # Configure this Daemon instance through a hash of options
  #
  # - config = a Hash with the configuration parameters
  #
  def self.configure(config)
    @@globalConfig[self] = config
  end

  #
  # Start a given Daemon identified by its name. If no daemon exist for the given name,
  # then create and start a new one
  #
  # - req = the HTTP Request used to request the dameon execution, and which contains its name
  #
  # [Return] the instance of newly started daemon
  #
  def self.start(req)
    d = self[daemon_name(req)]
    if (d == nil)
      d = self.new(req)
    elsif !d.running
      d = self.new(req)
    else
      d.ping  # somebody cares about you
    end
    return d
  end


  #
  # Stop a given Daemon identified by its name.
  #
  # - req = the HTTP Request used to request the dameon termination, and which contains its name
  #
  def self.stop(req)
    d = self[daemon_name(req)]
    if (d != nil)
      d.stop
    end
  end

  #
  # Execute a block of commands for all Daemons used by this Service
  #
  def self.each
    self.all do
      yield
    end
  end

  #
  # Return a particular Daemon instance used by this Service
  #
  # [Return] an instance of a Daemon
  #
  def self.[] (id)
    return @@inst[self].nil? ? nil : @@inst[self][id]
  end

  #
  # Return the instances of all Daemons used by this Service
  #
  # [Return] a list of all used Daemons
  #
  def self.all
    return @@inst[self].nil? ? [] : @@inst[self].values
  end

  #
  # Return the value of a given configuration parameter for a Daemon
  #
  # - req = the HTTP Request with all the parameters
  # - name = the name of the parameter to return
  #
  # [Return] a String with the value of the required parameter
  #
  def self.getDaemonParam(req, name)
    p = req.query[name]
    if (p == nil)
      raise HTTPStatus::BadRequest, "Missing parameter '#{name}'"
    end
    p
  end

  #
  # Return the value of a given configuration parameter for a Daemon,
  # if this parameter is not present in the request, return a default value
  #
  # - req = the HTTP Request with all the parameters
  # - name = the name of the parameter to return
  # - default = the default value to return
  #
  # [Return] a String with the value of the required parameter
  #
  def self.getDaemonParamDef(req, name, default)
    req.query[name] || default
  end

  #
  # Create a new instance of an AbstractDaemon
  #
  # - req = the HTTP Request that requests the daemon creation
  #
  def initialize(req)
    @name = self.class.daemon_name(req)
    super("#{self.class}:#{@name}")
    @domain = self.class.getDaemonParam(req, 'domain')
    @config  = getTestbedConfig(@domain)
    configDefaults(@config)

    instances = (@@inst[self.class] ||= {})
    if (instances.length >= @config['maxDaemons'])
      raise HTTPStatus::BadRequest,
        "Max. number of daemons reached. Shutdown others and try again"
    end

    @port = findPort()
    cmd = getCommand()
    run(cmd)
    instances[@name] = self
  end

  #
  # Load config file for this Service, assign default value to config
  # parameters when no value is specified in the config file.
  # Specific Daemon sub-class will override this method with its own defaults
  #
  def configDefaults(config)
  end

  #
  # Return the command string for starting the Daemon.
  # Specific Daemon sub-class will override this method with its own command line
  #
    def getCommand()
    raise "Missing implementation of 'getCommand'"
  end

  #
  # Return a given configuration Hash for this Daemon for a particular testbed
  #
  # - domain = name of the testbed to return the config for
  #
  # [Return] a Hash with the configuration parameters
  #
  def getTestbedConfig(domain)
    if ((dc = @@globalConfig[self.class]['testbed']) == nil)
      raise "Missing 'testbed' configuration"
    end
    config = dc[domain] || dc['default']
    if (config == nil)
      raise "Missing 'testbed' config for '#{domain}' or 'default'"
    end

    config['startPort'] ||= DEF_START_PORT
    config['maxDaemons'] ||= DEF_MAX_DAEMONS
    config['timeout'] ||= DEF_TIMEOUT

    config
  end

  #
  # Stop this particular Daemon instance
  #
  def stop()
    @running = false  # to avoid error message from termination
    # the "minus" terminates all processes with the group ID @pid
    # this ensures the child and all of its grandchildren are terminated
    # PROBLEM: the children are not terminated when the parent exits
    Process.kill("-TERM", @pid)
    Timer.cancel(@name)
    @@inst[self.class].delete(@name)
  end

  #
  # Return a free network Port on which this Daemon can listen for requests.
  # This 1st check an initial Port (specified in request or default), if not available
  # it increases the port number by one and check again, until it finds a free one.
  #
  # [Return] an available Port number
  #
  def findPort()
    # this is REALLY ugly
    port = @config['startPort']
    while true
      good = true
      #self.class.each { |v|
      #  if (v.port == port)
      #    good = false
      #    break
      #  end
      #}
      # Retrieve the list of all Daemons running
      if (@@inst[self.class] != nil)
        @@inst[self.class].each_value { |value|
          # For each Daemon, check its used port compared to our candidate one
          if (value.port == port)
            good = false
            break
          end
        }
      end
      if (good)
        begin
          info "Checking port #{port}..."
          serv = TCPServer.new(port)
        rescue
          good = false
          info "Port #{port} is in use!"
        else
          serv.close
          info "Port #{port} is free!"
        end
      end
      return port if (good)
      # The candidate port is already used, increase it and loop again...
      port += 1
    end
  end

  #
  # Execute the command line to run this Daemon. This method forks the current Thread to
  # execute the Daemon, then create a new Thread to monitor the correct termination of this
  # Daemon, and Timer (i.e. essentially another Thread) to monitor Daemon timeout.
  #
  # - cmd = the specific command line to run this Daemon
  #
  def run(cmd)
    @pipe = pipe = IO::pipe
    info "Starting #{cmd}"
    @running = true
    @pid = fork {
      # set the process group ID to the pid of the child
      # this way, the child and all grandchildren will be in the same process group
      # so we can terminate all of them with just one signal to the group
      Process.setpgid(0,Process.pid)
      begin
        exec(cmd)
      rescue
        pipe.puts "exec failed for '#{cmd.join(' ')}': #{$!}"
      end
      # Should never get here
      exit!
    }
    # Create thread which waits for application to exit
    Thread.new(@pid) {|pid|
      # try to attach to the process, repeat 4 times
      # sometimes it takes a few seconds before we can attach to a process
      retries = 4
      begin
        ret = Process.waitpid2(-pid)
      rescue
        if (retries -= 1) > 0
          sleep 1
          retry
        else
          error "Child exit status collection thread failed to wait for the process with 
PGID #{pid}. After its termination, it will remain in the process list as a zombie."
          ret = []
        end
      end
      status = ret[1]
      # app finished
      if ! status.success? && @running
        error "Daemon '#{@name}' failed (code=#{status.exitstatus})"
      end
      done()
    }
    # Create thread to time out daemon
    @timeout = @config['timeout']
    Timer.register(@name, @timeout) { stop }

    # check if that was successful
    sleep 1  # give it some time to start up
    if (! @running)
      raise "Starting daemon '#{@name}' with '#{cmd}' failed"
    end
  end

  #
  # Return the time in seconds before this Daemon instance will timeout
  #
    # [Return] a time in second
  #
  def untilTimeout()
    return Timer.timeRemaining(@name)
  end

  #
  # Ping this Daemon instance to prevent it from timing out
  #
  def ping()
    Timer.renew(@name, @timeout)
  end

  #
  # Do some cleaning after a Daemon termination
  #
  def done()
    info "'#{@name}' daemon done"
    @running = false
    @@inst[self.class].delete(@name)
  end

end
