#!/usr/bin/ruby
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
# = nodeAgent.rb
#
# == Description
#
# This class defines the Node Agent (NA) entity, which is a daemon
# running on an experimental node.The NA listens for commands
# from the Node Handler, and executes them on the node.
# The module AgentCommands contains the list of commands that the NA 
# understands.
#

### THIS require HAS TO COME FIRST! See http://omf.mytestbed.net/issues/show/19
require 'omf-resctl/omf_agent/agentPubSubCommunicator'
###
#require 'omf-resctl/omf_agent/communication'
require 'omf-resctl/omf_agent/agentCommands'
require 'date'
require 'omf-common/hash-ext'

#
# This class defines the Node Agent (NA) entity, which is a daemon
# running on an experimental node.The NA listens for commands
# from the Node Handler, and executes them on the node.
# The module AgentCommands contains the list of commands that the NA 
# understands.
#
class NodeAgent < MObject

  AGENT_VERSION = "4.4.0"

  # This attribut refers to the unique class instance (Singleton pattern)
  @@instance = nil

  #
  # Return the singleton instance of the Node Agent class
  #
  # [Return] the instance for this Node Agent
  #
  def self.instance
    if (@@instance == nil)
      @@instance = NodeAgent.new
    end
    return @@instance
  end


  #
  # Run the main execution loop of the Node Agent.
  # After starting the NA, this method will loop until
  # SIGINT (CTRL-C) or SIGTERM (init script) is received
  #
  def run
    if (! @running.nil?)
      raise "Already running"
    end
    info("NodeAgent V#{AGENT_VERSION}")
    reset

    @running = ConditionVariable.new
    if @interactive
      require 'irb'
      ARGV.clear
      ARGV << "--simple-prompt"
      ARGV << "--noinspect"
      IRB.start()
    else
      interrupted = false
      trap("INT") { interrupted = true }
      trap("TERM") { interrupted = true }
      loop do
        if interrupted
          communicator.quit
          ExecApp.killAll
          exit
        end
	      sleep 1
      end
    end
  end

  #
  # Return the x coordinate for this NA
  #
  # [Return] x coordinate of this NA
  #
  def x
    return @x = communicator.x
  end
  #
  # Return the y coordinate for this NA
  #
  # [Return] x coordinate of this NA
  #
  def y
    return @y = communicator.y
  end
  #
  # Return the Control IP address of this NA
  #
  # [Return] Control IP address of this NA
  #
  def localAddr
    return @localAddr = communicator.localAddr
  end

  #
  # Add an alias for this NA. If 'isPrimary' is true, then the provided 
  # alias will also be set as the NA's primary name. The first alias becomes 
  # the default name.
  #
  # - newAlias = a String with the new alias to add
  # - isPrimary = true/false, if true the new alias becomes the NA's primary name 
  #
  def addAlias(newAlias, isPrimary = false)
    if @names.length == 1 || isPrimary
      # the first alias will also become the new agent name
      @agentName = newAlias
    end
    if (@names.index(newAlias) != nil)
      MObject.debug("Alias '#{newAlias}' already registered.")
    else
      @names.insert(0, newAlias)
    end
    MObject.debug("Agent names #{@names.join(', ')}")
  end

  #
  # Send an OK reply to the Node Handler (NH). When a command has been 
  # successfully completed, the NA sends an 'HeartBeat' OK message
  # to the NH
  #
  # - cmd = a String with the command that completed successfully
  # - id = the ID of this NA (default = nil)
  # - msgArray = an array with the full received command (name, parameters,...)
  #
  def okReply(cmd, id = nil, *msgArray)
    if allowDisconnection? 
      communicator.sendRelaxedHeartbeat()
    else
      communicator.sendHeartbeat()
    end
  end

  #
  # Send an ERROR reply to the Node Handler (NH). When an error occured
  # while executing a command, the NA sends an 'ERROR' message
  # to the NH
  #
  # - cmd = a String with the command that produced the error
  # - id = the ID of this NA (default = nil)
  # - msgArray = an array with the full received command (name, parameters,...)
  #
  def errorReply(cmd, id = nil, *msgArray)
    send(:ERROR, cmd, id, *msgArray)
  end

  #
  # Send a text message to the Node Handler (NH). 
  #
  # - msgArray = an array with the full text message to send 
  #
  def send(*msgArray)
    if connected?
      communicator.send(*msgArray)
    else
      warn("Not sending message because not connected: ", msgArray.join(' '))
    end
  end

  #
  # Set the name of the disk image found when starting up
  #
  # [Return] a String with the disk image's name
  #
  def imageName()
    if (@imageName.nil?)
      if (File.exists?(AgentCommands::IMAGE_NAME_FILE))
        File.open(AgentCommands::IMAGE_NAME_FILE) { |f|
          @imageName = f.read.chomp
        }
      else
        @imageName = 'unknown'
        MObject.warn("Can't find '#{AgentCommands::IMAGE_NAME_FILE}'")
      end
    end
    @imageName
  end

  #
  # Send a message to the Node Handler (NH) when an event related
  # to a particular application has happened. This method is
  # usually called by ExecApp which monitors the application 
  # identified by 'id'.
  #
  # - eventName = a String with the name of event that occured
  # - appID = a String with the ID of the application raising the event 
  # - msg = a String with optional message from the application 
  #
  def onAppEvent(eventName, appId, *msg)
    debug("onAppEvent(#{eventName}:#{appId}): '#{msg}'")
    
    # If this NA allows disconnection, then check if the event is the Done message from 
    # the slave Experiment Controller
    if ( allowDisconnection? && (appId == AgentCommands.slaveExpCtlID) )
       if ( eventName.split(".")[0] == "DONE" )
       expirementDone 
       debug("#{appId} - DONE - EXPERIMENT DONE with status: #{eventName.split(".")[1]}")
       end
    end
    send(:APP_EVENT, eventName.to_s.upcase, appId, *msg)
  end

  #
  # Send a message to the Node Handler (NH) when an event related
  # to a particular device has happened. This method is
  # usually called by a Device instance reporting its state change
  #
  # - eventName = a String with the name of event that occured
  # - deviceName = a String with the name of the device raising the event 
  # - msg = a String with optional message from the device 
  #
  def onDevEvent(eventName, deviceName, *msg)
    debug("onDevEvent(#{eventName}:#{deviceName}): '#{msg}'")
    send(:DEV_EVENT, eventName.to_s.upcase, deviceName, *msg)
  end

  #
  # Reset all the internal states of this NA, stop all applications
  # started so far, and remove all loaded network modules
  #
  def reset
    info "\n------------ RESET ------------\n"
    ExecApp.killAll
    Device.unload
    #### ONLY FOR WINDOWS TESTING
    #    controlIP = localAddr || "10.10.2.3"
    #### END OF HACK
    resetState
    communicator.reset
  end

  # 
  # Reset all the internat states of this NA
  #
  def resetState
    @agentName = @defAgentName || "#{communicator.localAddr}"
    @connected = false
    @names = [@agentName]
    @allowDisconnection = false
    @expirementDone = false
    debug "Disconnection Support Disabled."
  end

  #
  # Set the 'Disconnection Support' flag to true
  #
  def allowDisconnection
    debug "Disconnection Support Enabled."
    @allowDisconnection = true
  end

  #
  # Return the value of the 'Disconnection Support'
  #
  # [Return] true/false
  #
  def allowDisconnection?
    return @allowDisconnection
  end 

  #
  # Set the 'Experiment Done' flag to true
  # Should be called when the 'slave' NH terminates
  #
  def expirementDone
    debug "Expirement is DONE"
    @expirementDone = true
  end

  #
  # Return the value of the 'Experiment Done' flag
  # This is true, when this NA has finished executing all the experiment
  # tasks for this node, and the node is now connectect to the Control Network,
  # and any outstanding measurments have been sent to the OML server by the OML 
  # proxy. 
  #
  # [Return] true/false
  #
  def expirementDone?
    return @expirementDone
  end 

  #
  # Return the primary name of this NA
  #
  # [Return] a String with the primary name of this NA
  #
  def agentName
    @agentName || @defAgentName || "#{communicator.localAddr}"
  end

  #
  # Return the connection status of this NA (i.e. is it connected to the NH?)
  #
  # [Return] true/false
  #
  def connected?
    @connected
  end

  #
  # Parse the command line arguments which were used when starting this NA
  #
  # - args = the command line arguments
  #
  def parseOptions(args)
    require 'optparse'

    cfgFile = nil
    @interactive = false
    @logConfigFile = ENV['NODE_AGENT_LOG'] || "/etc/omf-resctl/nodeagent_log.xml"

    # --listen-addr --listen-port --handler-addr --handler-port
    opts = OptionParser.new
    opts.banner = "Usage: nodeAgent [options]"
    @config = {'comm' => {}}

    # This option is relevant only when using a TCP Server Communicator
    opts.on("--server-port PORT",
      "Port to wait for handler to connect on") {|port|
      @config['comm']['server_port'] = port.to_i
    }

    # The following options are relevant only when using a Multicast Communicator or a TCPClient (broken?) one
    opts.on("--handler-addr ADDR",
      "Address of handler [#{@handlerAddr}]") {|addr|
      @config['comm']['handler_addr'] = addr
    }
    opts.on("--handler-port PORT",
      "Port handler is listening [#{@handlerPort}]") {|port|
      @config['comm']['handler_port'] = port.to_i
    }
    opts.on("--local-addr ADDR",
      "Address of local interface to use for multicast sockets") {|addr|
      @config['comm']['local_addr'] = addr
    }

    # The following options are relevant only when using a Multicast Communicator
    opts.on("--listen-addr ADDR",
      "Address to listen for handler commands [#{@listenAddr}]") {|addr|
      @config['comm']['listen_addr'] = addr
    }
    opts.on("--listen-port PORT",
      "Port to listen for handler commands [#{@listenPort}]") {|port|
      @config['comm']['listen_port'] = port.to_i
    }
    opts.on("--local-if IF",
      "Name of local interface to use for multicast sockets [#{@localIF}]") {|name|
      @config['comm']['local_if'] = name
    }

    # General options
    opts.on("-i", "--interactive",
      "Run the agent in interactive mode") {
      @interactive = true
    }
    opts.on("-l", "--libraries LIST",
      "Comma separated list of additional files to load [#{@extraLibs}]") {|list|
      @extraLibs = list
    }
    opts.on("--log FILE",
      "File containing logging configuration information") {|file|
      @logConfigFile = file
    }
    opts.on('--name NAME',
      "Initial checkin name of agent") {|name|
      @defAgentName = name
    }
    opts.on("-n", "--just-print",
      "Print the commands that would be executed, but do not execute them") {
      NodeAgent.JUST_PRINT = true
    }
    opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }
    opts.on_tail("-v", "--version", "Show the version") {
      puts NH_VERSION_STRING
      exit
    }

    rest = opts.parse(args)

    # Make sure log exists ...
    @logConfigFile = File.exists?(@logConfigFile) ? @logConfigFile : nil
    MObject.initLog('nodeAgent', nil, {:configFile => @logConfigFile})

    # read optional config file
    if cfgFile.nil?
      name = "nodeagent.yaml"
      path = ["../etc/omf-resctl/#{name}", "/etc/omf-resctl/#{name}"]
      cfgFile = path.detect {|f|
        File.readable?(f)
      }
    else
      if (!File.readable?(cfgFile))
        raise "Can't find configuration file '#{cfgFile}'"
      end
    end
    if (cfgFile.nil?)
      raise 'Can\'t find a configuration file'
    else
      require 'yaml'
      h = YAML::load_file(cfgFile)
      if ((p = h['nodeagent']) == nil)
        raise "Missing 'nodeagent' root in '#{cfgFile}'"
      end
      @config = p.merge_deep!(@config)
    end
  end

  #
  # Return the configuration parameter for 'key'
  #
  # - key =  a String with the name of the parameter to retrieve
  #
  def config(key)
    @config[key]
  end

  #
  # Return the instance of the Communicator module associated to this NA
  #
  # [Return] a Communicator object 
  #
  def communicator()
    AgentPubSubCommunicator.instance
  end

  #
  # Execute a command received from the NH
  #
  # - argArray = an array holding the full command to execute (name, parameters,...)
  #
  def execCommand(argArray)
    command = argArray.delete_at(0).upcase
    if (command == 'REBOOT')
      debug "Exec REBOOT cmd!"
    elsif (!@connected && command != 'YOUARE')
      # it's for us but ignore because we aren't in a connected state
      return
    end

    debug "Exec cmd '#{command}' with '#{argArray.join(' ')}'"
    fullcmd = "'#{command}' with '#{argArray.join(' ')}'"
    method = nil
    begin
      method = AgentCommands.method(command)
    rescue Exception
      error "Unknown command '#{command}'"
      send(:ERROR, :UNKNOWN_CMD, command)
      return
    end
    begin
      reply = method.call(self, argArray)
    rescue Exception => err
      error "While executing #{fullcmd}: #{err}"
      send(:ERROR, :EXECUTION, fullcmd, err)
      return
    end
    # Thierry: moved that code here 
    # to avoid sending 'HB' msg with source field set to IP addr instead of "n_x_y" to NH
    if (!@connected && command == 'YOUARE')
      @connected = true  # the nodeAgent knows us!
    end
  end

  ################################################
  private

  #
  # Start this Node Agent
  #
  def initialize
    # Name of image we booted into
    @imageName = nil
    @running = nil
  end

end

#
# Discover the available devices
# 
IO.popen("lspci | grep 'Network controller: Intel' | wc -l") {|p|
  if p.gets.to_i > 0
    require 'omf-resctl/omf_driver/intel'
    MObject.info "Have Intel cards"
    AgentCommands::DEV_MAPPINGS['net/w0'] = IntelDevice.new('net/w0', 'eth2')
    AgentCommands::DEV_MAPPINGS['net/w1'] = IntelDevice.new('net/w1', 'eth3')
  end
}
IO.popen("lspci | grep 'Ethernet controller: Atheros' | wc -l") {|p|
  if p.gets.to_i > 0
    require 'omf-resctl/omf_driver/atheros'
    MObject.info "Have Atheros cards"
    AgentCommands::DEV_MAPPINGS['net/w0'] = AtherosDevice.new('net/w0', 'ath0')
    AgentCommands::DEV_MAPPINGS['net/w1'] = AtherosDevice.new('net/w1', 'ath1')
  end
}

#
# Execution Entry point 
#
begin
 
  NodeAgent.instance.parseOptions(ARGV)
  NodeAgent.instance.run
rescue SystemExit
rescue Interrupt
  # ignore
rescue Exception => ex
  begin
    bt = ex.backtrace.join("\n\t")
    puts "Exception: #{ex} (#{ex.class})\n\t#{bt}"
  rescue Exception
  end
end
MObject.info("sys", "Exiting")
ExecApp.killAll
