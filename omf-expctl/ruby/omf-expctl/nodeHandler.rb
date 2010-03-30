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
# = nodeHandler.rb
#
# == Description
#
# This is the main source file for the Node Handler. It defines the NodeHandler class.
#
# NOTE: Originally 'Node Handler' (EC) was the name of this OMF entity. As of end of 2008
# we are adopting a new naming scheme closer to the GENI specifications. In this new scheme,
# the term 'Experiment Controller' (EC) replaces 'Node Handler'. This code will gradually
# be changed to reflect this. However, this is change is a low priority task, therefore the
# reader will see both terms 'EC' and 'EC' used in the code.
#


require 'omf-common/omfVersion'
require 'set'
require 'benchmark'
require 'thread'  # Queue class
require 'net/http'
require 'omf-expctl/exceptions'
require 'omf-common/mobject'
require 'omf-expctl/communicator/communicator.rb'
require 'omf-expctl/oconfig'
require 'singleton'
require 'omf-expctl/traceState'
require 'omf-expctl/experiment'
require 'omf-expctl/node/basicNodeSet'
require 'omf-expctl/node/groupNodeSet'
require 'omf-expctl/node/rootGroupNodeSet'
require 'omf-expctl/node/rootNodeSetPath'
require 'rexml/document'
require 'rexml/element'
require 'omf-common/web/webServer'
require 'omf-expctl/cmc'
require 'omf-expctl/antenna'
require 'omf-expctl/topology'
require 'omf-expctl/web/tab/log/logOutputter'

#require 'omf-expctl/web/tab/log/logServlet'

Project = nil

#
# This class implements the Node Handler, the entry point for 
# a user to run an experiment with OMF
#
class NodeHandler < MObject

  #
  # EC follows the 'singleton' design pattern
  #
  include Singleton

  #
  # Our Version Number
  #
  VERSION = OMF::Common::VERSION(__FILE__)
  MM_VERSION = OMF::Common::MM_VERSION()
  VERSION_STRING = "OMF Experiment Controller #{VERSION}"

  #
  # Where to find the default config files
  #
  DEFAULT_CONFIG_PATH = "/etc/omf-expctl"
  DEFAULT_CONFIG_FILE = "omf-expctl.yaml"
  DEFAULT_CONFIG_LOG = "omf-expctl_log.xml"

  #
  # XML Doc to hold all the experiment states
  #
  DOCUMENT = REXML::Document.new
  ROOT_EL = DOCUMENT.add(REXML::Element.new("context"))
  LOG_EL = ROOT_EL.add_element("log")
  EXPERIMENT_EL = ROOT_EL.add_element("experiment")
  NODES_EL = ROOT_EL.add_element("nodes")
  OML_EL = ROOT_EL.add_element("oml")#.add_element('experiment', {'id' => 'unamed_exp'})

  #
  # Name of tutorial experiment
  #
  TUTORIAL = 'test:exp:tutorial'

  #
  # Maximum Number of port to try for the builtin Web Server
  #
  MAXWEBTRY = 1000

  #
  # Pair of Mutex used to implement the NodeHandler's execution loop
  #
  @@mutex = Mutex.new
  @@blocker = ConditionVariable.new

  #
  # Flag for testing and methods to manipulate it. 
  # If true, don't send commands to node, just log actions   
  #
  @@justPrint = false

  # 
  # Flag indicating if this Experiment Controller (EC) is invoked for an Experiment
  # that support temporary disconnections
  #
  @@disconnectionMode = false

  #
  # Constant - Mount point where the Experiment Description should be served by the
  # EC's webserver
  #
  EXPFILE_MOUNT = "/ExperimentDescription"

  # 
  # Return the value of the 'runningSlaveMode' flag
  # The EC runs in 'slave mode' when it is invoked on a node/resource, which
  # can be potentially disconnected from the Control Network. The EC's operations in 
  # this mode are substantially different from its normal execution.
  #
  # [Return] true/false
  #
  def NodeHandler.SLAVE_MODE()
    return @@runningSlaveMode
  end 

  #
  # Return the value of the 'showAppOutput' flag
  # When this flag is 'true', the EC will display on its standard-out any outputs 
  # coming from the standard-out of the applications running on the nodes.
  #
  # [Return] true/false (default 'false')
  #
  def NodeHandler.SHOW_APP_OUTPUT()
    return @@showAppOutput
  end
  
  #
  # Return the value of the 'justPrint' attribut
  # If true, don't send commands to node, just log actions   
  # [Return] true/false
  #
  def NodeHandler.JUST_PRINT()
    return @@justPrint
  end

  #
  # Set the value of the 'justPrint' attribut
  # If true, don't send commands to node, just log actions   
  #
  # - flag = true/false
  #
  def NodeHandler.JUST_PRINT=(flag)
    @@justPrint = flag
  end

  #
  # Document root for web server. Need to wrap in setter/getters to
  # allow experiment script to change it as the web server is being
  # started before the experiment script is loaded.
  #
  @@webRoot = "#{ENV['HOME']}/public_html"

  #
  # Return the root URL for the EC's webserver
  #
  # [Return] an URL String
  #
  def NodeHandler.WEB_ROOT()
    @@webRoot
  end

  #
  # Set the root URL for the EC's webserver
  #
  # - root = an URL String
  #
  def NodeHandler.WEB_ROOT=(root)
    @@webRoot = root
  end

  #
  # ShutDown Flag: 
  # When 'true', shutdown after the experiment
  # Default is 'false'
  #
  @@shutdown = false  

  #
  # Return the value of the 'shutdown' flag
  #
  # [Return] true/false (default 'false')
  #
  def NodeHandler.SHUTDOWN()
    return @@shutdown
  end

  #
  # Set the value of the 'shutdown' flag
  #
  # - flag = true/false
  #
  def NodeHandler.SHUTDOWN=(flag)
    @@shutdown= flag
  end
  
  #
  # Reset Flag: 
  # When 'true', reset nodes before the experiment
  # Default is 'false'
  #
  @@reset = false
  
  #
  # Return the value of the 'reset' flag
  #
  # [Return] true/false (default 'false')
  #
  def NodeHandler.NODE_RESET()
    return @@reset
  end

  #
  # Set the value of the 'reset' flag
  #
  # - flag = true/false
  #
  def NodeHandler.NODE_RESET=(flag)
    @@reset= flag
  end

  # Attribut readers
  attr_reader :communicator, :expFile, :expFileURL, :omlProxyPort, :omlProxyAddr, :slaveNodeX, :slaveNodeY

  #
  # NodeHandler's methods...
  #

  #
  # Make a service call and return the HTTP response object. If the call fails
  # a ServiceException is raised.
  #
  # - url = URL to call
  # - error_msg = Message to include in exception if call fails
  #
  def NodeHandler.service_call(url, error_msg)
    debug("service call", url)
    if NodeHandler.JUST_PRINT
      puts "HTTP/GET #{url}"
    else
      begin
        response = Net::HTTP.get_response(URI.parse(url))
        if (! response.kind_of? Net::HTTPSuccess)
          raise ServiceException.new(response, error_msg)
        end
        response
      rescue Exception => ex
        fatal('service_call', "------------")
        fatal('service_call', "  A fatal error was encountered while making a request to an AM Service.")
        fatal('service_call', "  Request: '#{url}'")
        fatal('service_call', "  Exception: '#{ex}'")
        fatal('service_call', "------------")
        raise ServiceException.new(nil, ex)
      end
    end
  end

  #
  # Release the lock on @@blocker, this will wake up the main loop thread
  # and terminate the Node Handler execution
  #
  def NodeHandler.exit(hard = true)
    if (hard || !interactive?) 
      @@mutex.synchronize do
        @@blocker.signal
      end
    end
  end

  #
  # This method returns a time stamp to be used in XML tree
  # For example: it is called by "node.rb" and "tracestate.rb"
  # (Note: shall we just move this in whichever class is needing it?)
  #
  # [Return] a String of the current Time (timestamp)
  #
  def NodeHandler.getTS()
    return DateTime.now.strftime("%T")
  end

  #
  # Return the interactive state of the Node Handler
  #
  # [Return] true/false
  #
  def self.interactive?
    self.instance.interactive?
  end
  
  def interactive?
    @interactive
  end
  
  #
  # Return the interactive state of the Node Handler
  #
  # [Return] true/false
  #
  def self.debug?
    self.instance.debug?
  end
  
  def debug?
    @debug
  end

  # 
  # Set the Flag indicating that this Experiment Controller (EC) is invoked for an 
  # Experiment that support temporary disconnections
  #
  def NodeHandler.setDisconnectionMode()
    info "Disconnection support enabled for this Experiment"
    @@disconnectionMode = true
  end

  # 
  # Return the value of the Flag indicating that this Experiment Controller (EC) is 
  # invoked for an Experiment that support temporary disconnections
  #
  # [Return] true/false
  #
  def NodeHandler.disconnectionMode?()
    return @@disconnectionMode
  end

  #
  # Return the running state of the Node Handler
  # [Return] true/false
  #
  def running?()
    return @running
  end
  
  #
  # Return the instance of the Communicator module associated to this NA
  #
  # [Return] a Communicator object 
  #
  def communicator()
    Communicator.instance
  end

  #
  # This is the main running loop of Node Handler
  # It is called by the main execution loop located at the end of this file
  # After loading and starting the experiment, it will block waiting for a mutex.
  # When the experiment is done, a signal will be sent to release the mutex and unblock this method.
  #
  def run(main)
    if (@running != nil)
      raise "Already running"
    end
    @running = true
        
    Profiler__::start_profile if @doProfiling

    startWebServer()
    info "Web interface available at: #{OMF::Common::Web::url}"

    begin 
      require 'omf-expctl/handlerCommands'      
      if (@extraLibs)
        @extraLibs.split(',').each { |f|
          Experiment.load(f)
        }
      end
    end
    
    # Load the Experiment File , if any
    if @expFile
      Experiment.load(@expFile)
      Experiment.start()
    end
    
    # If EC is in 'Disconnection Mode' print a message for user on console
    if NodeHandler.disconnectionMode?
      whenAll("*", "status[@value='UP']") {
        info("", "Disconnection Mode - Waiting for all nodes to declare End of Experiment...")
        everyNS('*', 15) { |n|
          if !Node.allReconnected?
            info("still waiting...")
          else
            true
          end
        }
      }
    end
  
    if interactive?
      require 'omf-expctl/console'
      OMF::ExperimentController::Console.start
    end

    # Now block until the Experiment is Done...
    @@mutex.synchronize do
      @@blocker.wait(@@mutex)
    end
  end

  #
  # This method parse the command line arguments and set the relevant
  # configuration accordingly
  #
  # - args =  an Array with the command line arguments
  #
  def parseOptions(args)
    require 'optparse'

    runTutorial = false
    listTutorial = false

    @interactive = false
    @doProfiling = false
    @extraLibs = 'system:exp:stdlib'
    @logConfigFile = nil
    @finalStateFile = nil
    @webPort = 4000

    opts = OptionParser.new
    opts.banner = "\nExecute an experiment script\n\n" +
                  "Usage: #{ENV['ROOTAPP']} exec [OPTIONS] ExperimentName [-- EXP_OPTIONS]\n\n" +
                  "    ExperimentName is the filename of the experiment script\n" +
                  "    [EXP_OPTIONS] are any options defined in the experiment script\n" +
                  "    [OPTIONS] are any of the following:\n\n" 

    opts.on("-C", "--configfile FILE", "File containing local configuration parameters") {|file|
      @configFile = file
    }

    opts.on("-c", "--config NAME", "Configuration section from the config file ('default' if omitted)") {|name|
      OConfig.config = name
    }
    
    opts.on("-d", "--debug", "Operate in debug mode") { 
      @debug = true 
      OConfig.config = 'debug'
    }

    opts.on("-i", "--interactive", "Run the nodehandler in interactive mode") { @interactive = true }

    opts.on("-l", "--libraries LIST", "Comma separated list of additional files to load [#{@extraLibs}]") {|list|
      @extraLibs = list
    }

    opts.on("--log FILE", "File containing logging configuration information") {|file|
      @logConfigFile = file
    }

    opts.on("-m", "--message MESSAGE", "Message to add to experiment trace") {|msg|
      Experiment.message = msg
    }

    opts.on("-n", "--just-print", "Print the commands that would be executed, but do not execute them") { 
      NodeHandler.JUST_PRINT = true
    }

    opts.on("-p", "--print URI", "Print to the console the content of the experiment resource URI") {|uri|
      printResource(uri)
      exit
    }

    opts.on("--web-port PORT_NO", "Port to start web server on") {|port|
      @webPort = port.to_i
    }

    opts.on("-o", "--output-result FILE", "File to write final state information to") {|file|
      @finalStateFile = file
    }

    opts.on("-O", "--output-app-stdout", "Display on standard-out the outputs from the applications running on the nodes") { 
      @@showAppOutput = true
    }

    opts.on("-r", "--reset", "If set, then reset (reboot) the nodes before the experiment") { @@reset = true }

    opts.on("-S", "--slice NAME", "Name of the Slice where this EC should operate") { |name| Experiment.sliceID = name }

    opts.on("-s", "--shutdown", "If set, then shut down resources at the end of an experiment") { @@shutdown = true }

    opts.on("--tutorial", "Run a tutorial experiment (usage: '--tutorial -- --tutorialName tutorial-1a')") { runTutorial = true }

    opts.on("--tutorial-list", "List all the available tutorial") { listTutorial = true }

    opts.on("-t", "--tags TAGS", "Comma separated list of tags to add to experiment trace") {|tags|
      Experiment.tags = tags
    }

    opts.on_tail("-w", "--web-ui", "Control experiment through web interface") { @web_ui = true }

    opts.on_tail("-h", "--help", "Show this message") { |v| puts VERSION_STRING; puts opts; exit }

    opts.on_tail("-v", "--version", "Show the version\n") { |v| puts VERSION_STRING; exit }

    opts.on("--slave-mode EXPID", "Run EC in 'Slave' mode on a node that can be temporary disconnected, use EXPID for the Experiment ID") { |id|
      @@runningSlaveMode = true
      Experiment.ID = "#{id}"
    }

    opts.on("--slave-mode-omlport PORT", "When EC in 'Slave' mode, this is the PORT to the local proxy OML collection server") { |port|
      @omlProxyPort = port.to_i
    }

    opts.on("--slave-mode-omladdr ADDR", "When EC in 'Slave' mode, this is the Address to the local proxy OML collection server") { |addr|
      @omlProxyAddr = addr
    }

    opts.on("--slave-mode-xcoord X", "When EC in 'Slave' mode, this is the X coordinate of the node where this slave EC is running") { |x|
      @slaveNodeX = eval(x)
    }

    opts.on("--slave-mode-ycoord Y", "When EC in 'Slave' mode, this is the Y coordinate of the node where this slave EC is running") { |y|
      @slaveNodeY = eval(y)
    }

    #opts.on_tail("-p", "--profile", "Profile node handler") {
    #  require 'profiler'
    #  Thread.new() {
    #    f = File.new('profile.1', 'w')
    #    while true do
    #      t = sleep 60
    #      Profiler__::print_profile(f)
    #      f.flush
    #      Profiler__::reset_profile()
    #    end
    #  }
    #  doProfiling = true
    #}
   
    # Parse the command line
    rest = opts.parse(args)

    # Load the Configuration parameters for this EC
    loadControllerConfiguration()

    # Start the Logger for this EC
    startLogger()

    # Load the Configuration parameters for the default testbed of this EC
    # WARNING: No federation support yet, so for now the EC gets any 
    # testbed-specific information by assuming its domain is the same as 
    # the testbed name. In the future, we will have multiple testbed configs... 
    # And this will not be there, but rather provided by the resource provisioning
    OConfig.loadTestbedConfiguration()

    if Experiment.sliceID != nil
      info "Slice ID: #{Experiment.sliceID}"
    else
      if (Experiment.sliceID = OConfig[:ec_config][:slice]) != nil
        warn "Using default Slice ID (from config file): #{Experiment.sliceID}"
      else
        error "No slice ID defined on command line or config file! Exiting now!\n"
	exit
      end
    end
    info " Experiment ID: #{Experiment.ID}"

    if listTutorial
      OConfig.load("test:exp:tutorial-list" , true)
      exit
    end

    # Now start the Communiator
    Communicator.init(OConfig[:ec_config][:communicator], Experiment.sliceID, Experiment.ID)
    
    if @@runningSlaveMode
      info "Slave Mode on Node [#{@slaveNodeX},#{@slaveNodeY}] - OMLProxy: #{@omlProxyAddr}:#{@omlProxyPort}"
    end

    @expFile = nil
    if runTutorial
      @expFile = TUTORIAL
    end

    rest.each { |s|
      if s[0] == '-'[0]
        break
      end
      if (@expFile != nil)
        fatal('init', " Found additional experiment file '#{s}'")
        puts opts
        exit -1
      end
      @expFile = s
    }

    if (@expFile.nil? && ! (@interactive || @web_ui))
      fatal('init', " Missing experiment file")
      puts opts
      exit -1
    end

    Experiment.expArgs = rest - [@expFile]
  end

  #
  # This method loads the Experiment Controller config file
  # This config file contains the configuration for the EC
  #
  def loadControllerConfiguration()
    # First look for config file from the command line or the environment 
    cfg = @configFile || ENV['NODEHANDLER_CFG']
    if cfg != nil
      if ! File.exists?(cfg)
        raise "Can't find cfg file '#{cfg}'"
      end
    else
      # No luck, then look at our default paths...
      path = ["../#{DEFAULT_CONFIG_PATH}/#{DEFAULT_CONFIG_FILE}",
              "#{DEFAULT_CONFIG_PATH}-#{MM_VERSION}/#{DEFAULT_CONFIG_FILE}",
              "#{DEFAULT_CONFIG_PATH}/#{DEFAULT_CONFIG_FILE}"]
      path.each {|f|
        if File.exists?(f)
          cfg = f
        end
      }
      # Still no luck... we cannot continue without a config file
      if cfg == nil
        raise "Can't find #{DEFAULT_CONFIG_FILE} in #{path.join(':')}. You may find an example configuration file in '/usr/share/doc/omf-expctl-#{MM_VERSION}/examples'."
      end
    end
    # Now load the config file
    @configFile = cfg
    OConfig.init_from_yaml(@configFile)
  end

  #
  # This method starts the Logger for this Experiment Controller
  #
  def startLogger()
    # First look for log config file from the command line or the environment 
    log = @logConfigFile || ENV['NODEHANDLER_LOG'] || OConfig[:ec_config][:log] 
    if log != nil
      if ! File.exists?(log)
        raise "Can't find cfg file '#{log}' (for the EC logs)"
      end
    else
      # No luck, then look at our default paths...
      path =[".#{DEFAULT_CONFIG_LOG}",
             "~/.#{DEFAULT_CONFIG_LOG}",
             "#{DEFAULT_CONFIG_PATH}-#{MM_VERSION}/#{DEFAULT_CONFIG_LOG}",
             "#{DEFAULT_CONFIG_PATH}/#{DEFAULT_CONFIG_LOG}"]
      path.each {|f|
        if File.exists?(f)
          log = f
        end
      }
      # Still no luck... warn the user that all logs will be sent to stdout
      if log == nil
        warn "Can't find #{DEFAULT_CONFIG_LOG} in #{path.join(':')}"
      end
    end
    # Now start the logger
    @logConfigFile = log
    MObject.initLog('nodeHandler', Experiment.ID, {:configFile => @logConfigFile})
    debug("Using Log config file: #{@logConfigFile}")
    info(" #{VERSION_STRING}")
  end

  private

  #
  # Create a new NodeHandler
  #
  def initialize()
    #initialize_oml
    @@runningSlaveMode = false
    @@showAppOutput = false
    @omlProxyPort = nil
    @omlProxyAddr = nil
    @web_ui = false
  end

  #
  # This method prints the experiment resource, such as an experiment, prototype,
  # or application definition to the console.
  #
  # - uri = the URI referencing the experiment resources 
  #
  def printResource(uri)
    loadControllerConfiguration()
    res = OConfig.load(uri, false)
    if (res.nil?)
      puts "ERROR: Unknown uri '#{uri}'"
    else
      puts res[0]
    end
  end

  #
  # This method is called to shutdown the Node Handler.
  # This will immediately stop the processing of incoming, or pending message.
  # A reset message will be sent to all nodes and this
  # instance will be retired.
  #
  public
  def shutdown()
    info "Shutting down experiment, please wait."
    if (! @running)
      # nothing to do
      return
    end
    @processCommands = false

    begin
      communicator.sendReset
      if XmppCommunicator.instantiated?
        communicator.quit
      end
    rescue Exception
      #ignore
    end

    Antenna.each { |a|
      a.signal.off
    }

    # dump state
    begin
      if (@finalStateFile.nil?)
        @finalStateFile = "/tmp/#{Experiment.ID}-state.xml"
      end
      if (@finalStateFile == '-')
        ss = $stdout
      else
        ss = File.open(@finalStateFile, 'w')
      end
      ss.write("<?xml version='1.0'?>\n")
      #NodeHandler::DOCUMENT.write(ss, 2, true, true)
      NodeHandler::DOCUMENT.write(ss, 2)
    rescue Exception => ex
      debug("Exception while saving final state (#{ex})")
    end

    begin
      OMF::ExperimentController::Web::stop
    rescue Exception
      #ignore
    end

    if NodeHandler.SHUTDOWN
      info "Shutdown flag is set - Turning Off the resources"
      allGroups.pxeImage(OConfig.domain, false) # remove PXE links, if any
      allGroups.powerOff
    end
    @running = nil
  end

  #
  # This methode logs an error from 'source'.
  # The reason is described in string 'reason' with
  # additional information provided in hash table extra
  # (Example: this method is called by other methods in "agentCommads.rb")
  #
  # - source =  a String with the source of this error
  # - reason = a String describing the cause of this error
  # - extra = optional extra information provided as a Hash
  #
  # [Return] log id
  #
  def logError(source, reason, extra = nil)
    return log('error', source, reason, extra)
  end

  # Counter associated to the Log
  @@logCounter = 0

  #
  # Log a message with 'severity' from 'source'.
  # THe reason is described in string 'reason' with
  # additional information provided in hash table extra
  #
  # - severity = the degree of importance of this message
  # - source =  a String with the source of this message
  # - reason = a String describing the cause of this message
  # - extra = optional extra information provided as a Hash
  #
  # [Return] log id
  #
  def log(severity, source, reason, extra = nil)
    id = "log_#{@@logCounter += 1}"
    el = LOG_EL.add_element(severity, {'timeStamp' => Time.now, 'id' => id})
    el.text = reason
    if source.kind_of?(Node)
      el.add_attribute('source', source.nodeId)
    end
    extra.each {|k, v|
      el.add_element(k.to_s).text = v
    } if extra != nil
    return id
  end

  #
  # This method starts the EC's WebServer which will be used by nodes to retrieve
  # configuration info, e.g. OML configs  
  #
  def startWebServer(port = @webPort)
    accLog = MObject.logger('web::access')
    accLog.instance_eval {
      # Webrick only calls '<<' to log access information
      def << (msg)
        info(msg.strip)
      end
    }
    
    confirmedPort = 0
    #for i in port..port + MAXWEBTRY do
    for i in port..port do
      begin
        #info "Checking port #{i}..."
        serv = TCPServer.new(i)
        serv.close
        OMF::Common::Web::start(i, {
           :Logger => MObject.logger('web::server'),
           :DocumentRoot => NodeHandler.WEB_ROOT(),
           :AccessLog => [[accLog, "%h \"%r\" %s %b"]],
           :TabDir => "#{File.dirname(__FILE__)}/web/tab",
           :PublicHtml => OConfig[:ec_config][:repository][:path]
        })
        confirmedPort = i
      rescue Exception => ex
        info "Port #{i} is in use! (#{ex})"
        # Ignore this exception, 'i' will be incremented in the next loop
      end
      break if confirmedPort != 0   
    end
    
    if confirmedPort == 0
      error("Binding a free TCP port in the range #{port} to #{port+MAXWEBTRY} was unsuccessful. Giving up!")
      exit
    end
        
  end
end 
#
# END of the NodeHandler Class Declaration
