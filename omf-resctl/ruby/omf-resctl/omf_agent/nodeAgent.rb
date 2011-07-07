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

require 'omf-common/hash-ext'
require 'omf-common/omfVersion'
require 'omf-resctl/omf_agent/rcCommunicator'
require 'omf-resctl/omf_agent/agentCommands'

#
# This class defines the Node Agent (NA) entity, which is a daemon
# running on an experimental node.The NA listens for commands
# from the Node Handler, and executes them on the node.
# The module AgentCommands contains the list of commands that the NA 
# understands.
#
class NodeAgent < MObject

  #
  # Our Version Number
  #
  VERSION = OMF::Common::VERSION(__FILE__)
  OMF_MM_VERSION = OMF::Common::MM_VERSION()
  VERSION_STRING = "OMF Resource Controller #{VERSION}"
  
  # File containing image name
  IMAGE_NAME_FILE = '/.omf_imageid'

  # This attribut refers to the unique class instance (Singleton pattern)
  @@instance = nil

  attr_reader :agentName, :agentSlice, :config, :controlIP, :moteport, :motetype

  attr_accessor :allowDisconnection, :enrolled, :index

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
  # Run the main execution loop of the Resource Controller.
  # After starting the RC, this method will loop indefinitely
  #
  def run
    if (! @running.nil?)
      raise "Already running"
    end
    info(VERSION_STRING)
    resetState
    comm =  Hash.new
    comm[:hrn] = @agentName
    comm[:comms_name] = "#{@agentSlice}-#{@agentName}"
    comm[:handler] = self
    comm[:createflag] = false
    comm[:config] = @config[:communicator]
    comm[:sliceID] = @agentSlice
    comm[:domain] = @agentDomain 
    RCCommunicator.instance.init(comm)
    RCCommunicator.instance.reset

    @running = ConditionVariable.new
    if @interactive
      require 'irb'
      ARGV.clear
      ARGV << "--simple-prompt"
      ARGV << "--noinspect"
      IRB.start()
    else
      @mutex = Mutex.new
      @mutex.synchronize {
        @running.wait(@mutex)
      }
    end
  end


  #
  # Set the name of the disk image found when starting up
  #
  # [Return] a String with the disk image's name
  #
  def imageName()
    if (@imageName.nil?)
      if (File.exists?(IMAGE_NAME_FILE))
        File.open(IMAGE_NAME_FILE) { |f|
          @imageName = f.read.chomp
        }
      else
        @imageName = 'unknown'
        MObject.warn("Can't find '#{IMAGE_NAME_FILE}'")
      end
    end
    @imageName
  end

  #
  # Receive an event from one of the application that we have started.
  # This method is normally called by ExecApp which monitors the applications 
  # that we started. Applications are identified by 'id'.
  #
  # - eventName = a String with the name of event that occured
  # - appID = a String with the ID of the application raising the event 
  # - msg = a String with optional message from the application 
  #
  def onAppEvent(eventName, appID, *msg)
    event = :APP_EVENT
    debug("onAppEvent(event: #{eventName} - app: #{appID}) - '#{msg}'")
    # If this NA allows disconnection, then check if the event is the Done 
    # message from the slave Experiment Controller
    if @allowDisconnection && (appID.to_sym == :SLAVE_EC) 
       if eventName.split(".")[0] == "DONE"
         @expirementDone = true
         event = :END_EXPERIMENT
         debug("#{appID} is done - EXPERIMENT DONE with status: "+
               "#{eventName.split(".")[1]}")
       end
    end
    # Send the event to our EC
    RCCommunicator.instance.send_event(event, eventName.to_s.upcase, 
                                       appID, "#{msg}")
  end

  #
  # Receive an event from one of the device that we configured. 
  # This method is normally called by a Device instance reporting its state 
  #
  # - eventName = a String with the name of event that occured
  # - deviceName = a String with the name of the device raising the event 
  # - msg = a String with optional message from the device 
  #
  def onDevEvent(eventName, deviceName, *msg)
    debug("onDevEvent(#{eventName}:#{deviceName}): '#{msg}'")
    RCCommunicator.instance.send_event(:DEV_EVENT, eventName.to_s.upcase, 
                                       deviceName, "#{msg}")
  end

  #
  # Reset all the internal states of this NA, stop all applications
  # started so far, and remove all loaded network modules
  #
  def reset
    if @allowDisconnection && (ExecApp[:OML_PROXY] != nil)
      ExecApp[:OML_PROXY].stdin('OMLPROXY-RESUME')
      # HACK! begin
      # We need a way to find out when OML Proxy is done sending the 
      # collected measurements to the OML Server!
      sleep 30 
      # HACK! end
    end
    info "\n\n------------ RESET ------------\n"
    ExecApp.killAll
    AgentCommands.reset_links
    AgentCommands::DEV_MAPPINGS.each do |key,device|
      device.unload
    end
    resetState
    RCCommunicator.instance.reset
  end

  # 
  # Reset all the internat states of this NA
  #
  def resetState
    @enrolled = false
    @index = 0
    @allowDisconnection = false
    @expirementDone = false
    info "Agent: '#{@agentName}' - Slice: '#{@agentSlice}'"
    info "Disconnection Support Disabled."
  end

  # 
  # Make sure that we cleaning up before exiting...
  #
  def cleanUp
    if @running != nil
      info("Cleaning: Shutting down communicator")
      RCCommunicator.instance.stop
      info("Cleaning: Kill all previously started Applications")
      ExecApp.killAll
      info("Cleaning: Exit")
      info("\n\n------------ EXIT ------------\n")
    end
  end

  #
  # Parse the command line arguments which were used when starting this NA
  #
  # - args = the command line arguments
  #
  def parseOptions(args)
    require 'optparse'

    @configFile = nil
    @interactive = false
    @logConfigFile = ENV['NODE_AGENT_LOG'] || 
                     "/etc/omf-resctl-#{OMF_MM_VERSION}/omf-resctl_log.xml"
    private_key = nil
    public_key_dir = nil

    opts = OptionParser.new
    opts.banner = "Usage: nodeAgent [options]"
    @config = {:communicator => {}, :agent => {}}
    @config[:communicator] = {:xmpp => {}}

    # Communication Options 
    opts.on("--control-if IF",
    "Name of interface attached to the control and management network") {|name|
      @config[:communicator][:control_if] = name
      @controlIF = name
    }
    opts.on("--pubsub-gateway HOST",
    "Hostname of the local PubSub server to connect to") {|name|
      @config[:communicator][:xmpp][:pubsub_gateway] = name
    }
    opts.on("--pubsub-port PORT",
      "Port number of the Pubsub Gateway") {|port|
        @config[:communicator][:xmpp][:pubsub_port] = port
    }
    opts.on("--pubsub-use-dnssrv",
      "Look for DNS SRV record to locate the Pubsub Gateway") {
        @config[:communicator][:xmpp][:pubsub_use_dnssrv] = true
    }
    opts.on("--pubsub-user NAME",
      "Username for connecting to the local PubSub server (if not set, RC "+
      "will register its own new user)") {|name|
        @config[:communicator][:xmpp][:pubsub_user] = name
    }
    opts.on("--pubsub-pwd PWD",
      "Password for connecting to the local PubSub server (if not set, RC "+
      "will register its own new user)") {|name|
        @config[:communicator][:xmpp][:pubsub_pwd] = name
    }
    opts.on("--pubsub-domain HOST",
      "Hostname of the PubSub server hosting the Slice of this agent (if not "+
      "set, RC will use the same server as the 'pubsub-gateway'") {|name|
        @config[:communicator][:xmpp][:pubsub_domain] = name
    }
  
    # Instance Options
    opts.on('--name NAME',
      "Initial checkin name of agent (unique HRN for this resource)") {|name|
        @config[:agent][:name] = name
    }
    opts.on('--slice NAME',
      "Initial checkin slice of agent (unique HRN for the slice)") {|name|
        @config[:agent][:slice] = name
    }

    # Signing/Verification Options
    opts.on("-p", "--private_key FILE", "Set your RSA/DSA SSH private key "+
      "file location") { |file| 
      @config[:communicator][:private_key] = file 
    }
    opts.on("-P", "--public_key_dir DIRECTORY", "Set the directory holding "+
      "the public keys of your OMF peers") { |dir| 
      @config[:communicator][:public_key_dir] = dir 
    }  
    opts.on("-a", "--auth YES|NO", "Enable or disable signature checks and "+
      "message signing (default is no)") { |auth|
      @config[:communicator][:authenticate_messages] = (auth.downcase == "yes") 
    }

    # Mote-related Options
    opts.on('--moteport PORT',
      "For RCs servicing MoteApplications, this is the USB port that the RC "+
      "will bind") {|port|
      @moteport = port
    }
    opts.on('--motetype TYPE',
      "For RCs servicing MoteApplications, this is the type of mote that is "+
      "connected to this RC") {|mtype|
      @motetype = mtype
    }

    # General Options
    opts.on("-i", "--interactive",
      "Run the agent in interactive mode") {
        @interactive = true
    }
    opts.on("-l", "--libraries LIST",
      "Comma separated list of additional files to load "+
      "[#{@extraLibs}]") {|list|
        @extraLibs = list
    }
    opts.on("--log FILE",
      "File containing logging configuration information") {|file|
        @logConfigFile = file
    }
    opts.on("-C", "--configfile FILE",
      "File containing local configuration parameters") {|file|
        @configFile = file
    }
    opts.on("-n", "--just-print",
      "Print the commands that would be executed, but do not execute them") {
        NodeAgent.JUST_PRINT = true
    }
    opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }
    opts.on_tail("-v", "--version", "Show the version") {
      puts VERSION_STRING
      exit
    }

    rest = opts.parse(args)

    # Make sure log exists ...
    @logConfigFile = File.exists?(@logConfigFile) ? @logConfigFile : nil
    MObject.initLog('nodeAgent', nil, {:configFile => @logConfigFile})

    # read optional config file
    if !@configFile
      name = "omf-resctl.yaml"
      path = ["../etc/omf-resctl/#{name}", 
              "/etc/omf-resctl-#{OMF_MM_VERSION}/#{name}"]
      @configFile = path.detect {|f|
        File.readable?(f)
      }
    else
      if (!File.readable?(@configFile))
        raise "Can't find the configuration file '#{@configFile}'."+
              "You may find an example configuration file in "+
              "'/usr/share/doc/omf-resctl-#{OMF_MM_VERSION}/examples'."
      end
    end
    if !@configFile
      raise "Can't find any configuration files in the default paths. "+ 
      "Please create a config file at one of the default paths "+
      "(see install doc). Also, you may find an example configuration "+
      "file in '/usr/share/doc/omf-resctl-#{OMF_MM_VERSION}/examples'."
    else
      require 'yaml'
      h = YAML::load_file(@configFile)
      if ((p = h[:rcontroller]) == nil)
        raise "Missing ':rcontroller' root in '#{@configFile}'"
      end
      @config = p.merge_deep!(@config)
    end

    # At this point, we should now have a name and a slice
    if @config[:agent][:name] == nil || @config[:agent][:slice] == nil
      raise "Name or Slice are not defined in config file or as arguments!"
    end
    # substitute hostname or mac addr, if required
    @config[:agent][:name].gsub!(/%hostname%/, `/bin/hostname`.chomp)
    @config[:agent][:name].gsub!(/%fqdn%/, `/bin/hostname --fqdn`.chomp)
    @config[:agent][:name].gsub!(/%macaddr%/, `ifconfig #{@config[:communicator][:control_if]} | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}'`.chomp)
    @agentName = @config[:agent][:name] 
    @agentSlice =  @config[:agent][:slice] 
    @agentDomain = @config[:communicator][:xmpp][:pubsub_domain] || 
                   @config[:communicator][:xmpp][:pubsub_gateway]

    if @config[:communicator][:control_if] != nil
      @controlIF = @config[:communicator][:control_if]
      @controlIP = `ifconfig #{@controlIF} | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}'`.chomp
    end
  end

  ################################################
  private

  #
  # Start this Node Agent
  #
  def initialize
    @agentName = nil
    @agentSlice = nil
    # Name of image we booted into
    @imageName = nil
    @running = nil
    @controlIP = nil
    @controlIF = nil
  end

end

# Convenience funtion for getting the NodeAgent instance.
def controller
  NodeAgent.instance
end

#
# Discover the available devices
# 

if (File.exist?("/usr/bin/lspci"))
  # Debian/Ubuntu
  LSPCI="/usr/bin/lspci"
elsif (File.exist?("/sbin/lspci"))
  # Fedora
  LSPCI="/sbin/lspci"
else
  MObject.info "lspci not found, unable to detect the wireless hardware. Please install the 'pciutils' package."
end

if (LSPCI)
  IO.popen("#{LSPCI} | grep 'Network controller: Intel' | /usr/bin/wc -l") {|p|
    if p.gets.to_i > 0
      require 'omf-resctl/omf_driver/intel'
      MObject.info "Have Intel cards"
      AgentCommands::DEV_MAPPINGS['net/w0'] = IntelDevice.new('net/w0', 'eth2')
      AgentCommands::DEV_MAPPINGS['net/w1'] = IntelDevice.new('net/w1', 'eth3')
    end
  }
  IO.popen("#{LSPCI} | grep 'Ethernet controller: Atheros' | /usr/bin/wc -l") {|p|
    if p.gets.to_i > 0
      require 'omf-resctl/omf_driver/atheros'
      MObject.info "Have Atheros cards - Using MadWifi driver"
      AgentCommands::DEV_MAPPINGS['net/w0'] = AtherosDevice.new('net/w0', 'ath0')
      AgentCommands::DEV_MAPPINGS['net/w1'] = AtherosDevice.new('net/w1', 'ath1')
    end
  }
  IO.popen("#{LSPCI} | grep 'Network controller: Atheros' | /usr/bin/wc -l") {|p|
    if p.gets.to_i > 0
      require 'omf-resctl/omf_driver/ath9k'
      MObject.info "Have Atheros cards - Using ath9k driver"
      AgentCommands::DEV_MAPPINGS['net/w0'] = Ath9kDevice.new('net/w0', 'wlan0')
      AgentCommands::DEV_MAPPINGS['net/w1'] = Ath9kDevice.new('net/w1', 'wlan1')
    end
  }
  IO.popen("#{LSPCI} | grep 'Network controller: Intel Corporation Centrino Advanced-N + WiMAX' | /usr/bin/wc -l") {|p|
    if p.gets.to_i > 0
      require 'omf-resctl/omf_driver/wimaxcu'
      MObject.info "Found Intel WiMAX - using wimaxcu interface"
      AgentCommands::DEV_MAPPINGS['net/x0'] = WimaxcuDevice.new('net/x0', 'wmx0')
      AgentCommands::DEV_MAPPINGS['net/x1'] = WimaxcuDevice.new('net/x1', 'wmx1')
    end
  }
end

#
# Execution Entry point 
#
begin
  NodeAgent.instance.parseOptions(ARGV)
  NodeAgent.instance.run
# Exit when SIGTERM or INTERRUPT signal are received
# Or when an runtime exception occured
rescue SystemExit # ignore
rescue Interrupt # ignore
rescue SignalException # ignore
rescue Exception => ex
  begin
    bt = ex.backtrace.join("\n\t")
    puts "Exception: #{ex} (#{ex.class})\n\t#{bt}"
  rescue Exception
  end
end
#
# Make sure we clean up before exiting...
#
NodeAgent.instance.cleanUp
