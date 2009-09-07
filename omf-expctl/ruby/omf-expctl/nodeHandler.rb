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
# NOTE: Originally 'Node Handler' (NH) was the name of this OMF entity. As of end of 2008
# we are adopting a new naming scheme closer to the GENI specifications. In this new scheme,
# the term 'Experiment Controller' (EC) replaces 'Node Handler'. This code will gradually
# be changed to reflect this. However, this is change is a low priority task, therefore the
# reader will see both terms 'EC' and 'NH' used in the code.
#

require 'omf-expctl/version'

###
require 'set'
require 'benchmark'
require 'thread'  # Queue class
require 'net/http'
require 'omf-expctl/exceptions'
require 'omf-common/mobject'
require 'omf-expctl/communicator/communicator.rb'
require 'omf-expctl/oconfig'
#
require 'singleton'
require 'omf-expctl/version'
require 'omf-expctl/traceState'
require 'omf-expctl/experiment'
require 'omf-expctl/node/basicNodeSet'
require 'omf-expctl/node/groupNodeSet'
require 'omf-expctl/node/rootGroupNodeSet'
require 'omf-expctl/node/rootNodeSetPath'
require 'rexml/document'
require 'rexml/element'
require 'omf-expctl/web/webServer'
require 'omf-expctl/cmc'
require 'omf-expctl/antenna'
require 'omf-expctl/topology'
require 'omf-expctl/web/tab/log/logServlet'

Project = nil

#
# This class implements the Node Handler, the entry point for 
# a user to run an experiment with OMF
#
class NodeHandler < MObject

  #
  # NH follows the 'singleton' design pattern
  #
  include Singleton

  #
  # Where to find the default config files
  #
  DEFAULT_CONFIG_PATH = "/etc/omf-expctl"
  DEFAULT_CONFIG_FILE = "nodehandler.yaml"
  DEFAULT_CONFIG_LOG = "nodehandler_log.xml"

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
  # Flag indicating if this Experiment Controller (NH) is invoked for an Experiment
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
  # When this flag is 'true', the NH will display on its standard-out any outputs 
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
  # Return the root URL for the NH's webserver
  #
  # [Return] an URL String
  #
  def NodeHandler.WEB_ROOT()
    @@webRoot
  end

  #
  # Set the root URL for the NH's webserver
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
  def NodeHandler.RESET()
    return @@reset
  end

  #
  # Set the value of the 'reset' flag
  #
  # - flag = true/false
  #
  def NodeHandler.RESET=(flag)
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
        fatal('service_call', "Exception: #{ex} (#{url})")
        raise ServiceException.new(nil, ex)
      end
    end
  end

  #
  # Release the lock on @@blocker, this will wake up the main loop thread
  # and terminate the Node Handler execution
  #
  def NodeHandler.exit()
    @@mutex.synchronize {
      @@blocker.signal
    }
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
  # Set the Flag indicating that this Experiment Controller (NH) is invoked for an 
  # Experiment that support temporary disconnections
  #
  def NodeHandler.setDisconnectionMode()
    info "Disconnection support enabled for this Experiment"
    @@disconnectionMode = true
  end

  # 
  # Return the value of the Flag indicating that this Experiment Controller (NH) is 
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
    info "Web interface available at: #{OMF::ExperimentController::Web::url}"

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
      OMF::ExperimentController::Console.instance.run
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

    opts.on("-c", "--config FILE", "File containing local configuration parameters") {|file|
      @configFile = file
    }

    opts.on("-d", "--domain NAME", "Resource domain. Usually the name of the testbed") {|name|
      OConfig.domain = name
    }
    
    opts.on("-D", "--debug", "Operate in debug mode") {|name|
      @debug = true
    }


    opts.on("-i", "--interactive", "Run the nodehandler in interactive mode") {
      @interactive = true
    }

    # Deprecated
    #opts.on("-k", "--keep-up", "Keep the grid up after the experiment finished") {
    #  NodeHandler.SHUTDOWN = false
    #}

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

    opts.on("-r", "--result FILE", "File to write final state information to") {|file|
      @finalStateFile = file
    }

    opts.on("-s", "--shutdown flag", "If true, shut down resources at the end of an experiment [#{NodeHandler.SHUTDOWN}]") {|flag|
      NodeHandler.SHUTDOWN = (flag == 'true') || (flag == 'yes')
    }

    opts.on("-R", "--reset flag", "NOT IMPLEMENTED: If true, reset (reboot) the nodes before the experiment [#{NodeHandler.RESET}]") {|flag|
      NodeHandler.RESET = (flag == 'true') || (flag == 'yes')
    }

    opts.on("--tutorial", "Run tutorial [#{TUTORIAL}]") {
      runTutorial = true
    }

    opts.on("-t", "--tags TAGS", "Comma separated list of tags to add to experiment trace") {|tags|
      Experiment.tags = tags
    }

    opts.on_tail("-w", "--web-ui", "Control experiment through web interface") {
      @web_ui = true
    }

    opts.on_tail("-h", "--help", "Show this message") { puts OMF::ExperimentController::VERSION_STRING; puts opts; exit }
    opts.on_tail("-v", "--version", "Show the version\n") { puts OMF::ExperimentController::VERSION_STRING; exit }

    opts.on("--slave-mode EXPID", "Run NH in 'Slave' mode on a node that can be temporary disconnected, use EXPID for the Experiment ID") { |id|
      @@runningSlaveMode = true
      Experiment.ID = "#{id}"
    }

    opts.on("--slave-mode-omlport PORT", "When NH in 'Slave' mode, this is the PORT to the local proxy OML collection server") { |port|
      @omlProxyPort = port.to_i
    }

    opts.on("--slave-mode-omladdr ADDR", "When NH in 'Slave' mode, this is the Address to the local proxy OML collection server") { |addr|
      @omlProxyAddr = addr
    }

    opts.on("--slave-mode-xcoord X", "When NH in 'Slave' mode, this is the X coordinate of the node where this slave NH is running") { |x|
      @slaveNodeX = eval(x)
    }

    opts.on("--slave-mode-ycoord Y", "When NH in 'Slave' mode, this is the Y coordinate of the node where this slave NH is running") { |y|
      @slaveNodeY = eval(y)
    }

    opts.on("-A", "--show-app-output", "Display on standard-out the outputs from the applications running on the nodes") {
      @@showAppOutput = true
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

    # Now start the Communiator
    Communicator.init(OConfig[:ec_config][:communicator])
    
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
        fatal('init', "Found additional experiment file '#{s}'")
        puts opts
        exit -1
      end
      @expFile = s
    }

    if (@expFile.nil? && ! (@interactive || @web_ui))
      fatal('init', "Missing experiment file")
      puts opts
      exit -1
    end

    info('init', " Experiment ID: #{Experiment.ID}")
    Experiment.expArgs = rest - [@expFile]
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
              "#{DEFAULT_CONFIG_PATH}#{OMF::ExperimentController::VERSION}/#{DEFAULT_CONFIG_FILE}",
              "#{DEFAULT_CONFIG_PATH}/#{DEFAULT_CONFIG_FILE}"]
      path.each {|f|
        if File.exists?(f)
          cfg = f
        end
      }
      # Still no luck... we cannot continue without a config file
      if cfg == nil
        raise "Can't find #{DEFAULT_CONFIG_FILE} in #{path.join(':')}"
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
    log = @logConfigFile || ENV['NODEHANDLER_LOG']
    if log != nil
      if ! File.exists?(log)
        raise "Can't find cfg file '#{log}' (for the EC logs)"
      end
    else
      # No luck, then look at our default paths...
      path =[".#{DEFAULT_CONFIG_LOG}",
             "~/.#{DEFAULT_CONFIG_LOG}",
             "#{DEFAULT_CONFIG_PATH}#{OMF::ExperimentController::VERSION}/#{DEFAULT_CONFIG_LOG}",
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
    debug('init', "Using Log config file: #{@logConfigFile}")
    info('init', " #{OMF::ExperimentController::VERSION_STRING}")
  end

  #
  # This method prints the experiment resource, such as an experiment, prototype,
  # or application definition to the console.
  #
  # - uri = the URI referencing the experiment resources 
  #
  def printResource(uri)
    loadConfiguration()
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
      warn("Exception while saving final state (#{ex})")
    end

    begin
      OMF::ExperimentController::Web::stop
    rescue Exception
      #ignore
    end
    if NodeHandler.SHUTDOWN
      # TODO: only shut down nodes from this experiment
      #CMC::nodeAllOffSoft()
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
  # This method starts the NH's WebServer which will be used by nodes to retrieve
  # configuration info, e.g. OML configs  
  #
  def startWebServer(port = @webPort)
    accLog = Logger.new("w_access")
    accLog.instance_eval {
      def << (msg)
        debug('web::access', msg.strip)
      end
    }
    begin
        OMF::ExperimentController::Web::start(port, {:Logger => Logger.new("w_internal"),
             :DocumentRoot => NodeHandler.WEB_ROOT(),
             :AccessLog => [[accLog, "%h \"%r\" %s %b"]]})
    rescue Exception => except
        warn("Received '#{except}' when starting NH webserver (port: '#{port}')")
        warn("There may be another NH already running on the same testbed...")
        newPort = port + 1;
        if (newPort >= (@webPort + MAXWEBTRY))
          error("Already tried '#{MAXWEBTRY}' times to start NH webserver. Giving up!")
          exit
        else
          warn("Trying again with another port (port: '#{newPort}')...")
          return startWebServer(newPort)
        end
    end
  end

end 
#
# END of the NodeHandler Class Declaration
