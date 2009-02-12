#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 WINLAB, Rutgers University, USA
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

NH_REVISION = "$Revision: 1921 $".split(":")[1].chomp("$").strip
NH_VERSION_STRING = "NodeHandler Version #{$NH_VERSION} (#{NH_REVISION})"

require 'set'
require 'benchmark'
require 'thread'  # Queue class
require 'net/http'
require 'handler/exceptions'
require 'util/mobject'
require 'singleton'
require 'handler/traceState'
require 'handler/experiment'
require 'handler/oconfig'
require 'handler/nodeSet'
require 'handler/handlerCommands'
require 'rexml/document'
require 'rexml/element'
require 'handler/nodeHandlerServer'
require 'handler/cmc'
require 'handler/antenna'
require 'handler/communicator'
require 'handler/topology'

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
  # Version Info
  #
  VERSION = "$Revision: 1272 $".split(":")[1].chomp("$").strip
  MAJOR_V = $NH_VERSION.split('.')[0]

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
  # When 'true', shutdown nodes before and after the experiment
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

  # Attribut readers
  attr_reader :communicator

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
        MObject.fatal('service_call', "Exception: #{ex} (#{url})")
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
  # Return the running state of the Node Handler
  # [Return] true/false
  #
  def running?()
    return @running
  end

  #
  # This is the main running loop of Node Handler
  # It is called by the main execution loop located at the end of this file
  # After loading and starting the experiment, it will block waiting for a mutex.
  # When the experiment is done, a signal will be sent to release the mutex and unblock this method.
  #
  def run()
    if (@running != nil)
      raise "Already running"
    end
    @running = true
    
    if NodeHandler.SHUTDOWN
      # make sure, everything is switched off before starting
      CMC::nodeAllOffSoft()
      info "Shutdown Flag Set - Switching all nodes Off..."
      Kernel.sleep 5
    end
    # Placeholder when XMPP-based Pub/Sub Communicator will be ready for integration
    # Communicator.instance.configure(sid, userjid, userpassword, pubsubjid)  # configure our Pub/Sub Communicator
    Communicator.instance.sendReset  # if the nodes are already up, reset the agent now

    Profiler__::start_profile if @doProfiling

    startWebServer()

    # with OMLv2 we do not need to wait for application(s) setup to start the collection server
    OmlApp.startCollectionServer

    if (@extraLibs)
      @extraLibs.split(',').each { |f|
        Experiment.load(f)
      }
    end
    if @expFile
      Experiment.load(@expFile)
    end

    Experiment.start()

    if (! interactive?)
      @@mutex.synchronize {
        @@blocker.wait(@@mutex)
      }
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
      Experiment.domain = name
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

    opts.on("-s", "--shutdown flag", "If true, shut down grid at the end of an experiment [#{NodeHandler.SHUTDOWN}]") {|flag|
      NodeHandler.SHUTDOWN = (flag == 'true') || (flag == 'yes')
    }

    opts.on("--tutorial", "Run tutorial [#{TUTORIAL}]") {
      runTutorial = true
    }

    opts.on("-t", "--tags TAGS", "Comma separated list of tags to add to experiment trace") {|tags|
      Experiment.tags = tags
    }

    opts.on_tail("-h", "--help", "Show this message") { puts opts; exit }
    opts.on_tail("-v", "--version", "Show the version\n") {
      puts NH_VERSION_STRING
      exit
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

    rest = opts.parse(args)
    # create the loggers.
    if (@logConfigFile == nil)
      @logConfigFile = findDefaultLogConfigFile
    end
    #MObject.info('init', "Using LogFile: #{@logConfigFile}")
    loadGridConfigFile()

    MObject.initLog('nodeHandler', Experiment.ID, {:configFile => @logConfigFile})
    MObject.info('init', NH_VERSION_STRING)

    @expFile = nil
    if runTutorial
      @expFile = TUTORIAL
    end

    rest.each { |s|
      if s[0] == '-'[0]
        break
      end
      if (@expFile != nil)
        MObject.fatal('init', "Found additional experiment file '#{s}'")
        puts opts
        exit -1
      end
      @expFile = s
    }

    if (@expFile.nil? && ! @interactive)
      MObject.fatal('init', "Missing experiment file")
      puts opts
      exit -1
    end

    MObject.info('init', "Experiment ID: #{Experiment.ID}")
    Experiment.expArgs = rest - [@expFile]
  end

  #
  # This method loads the Node Handler config file
  # This config file contains the relevant configuration for the current testbed
  #
  def loadGridConfigFile()
    cfg = @configFile || ENV['NODEHANDLER_CFG']
    if cfg != nil
      if ! File.exists?(cfg)
        raise "Can't find cfg file '#{cfg}'"
      end
      OConfig.init(cfg)
      return
    end
    cfgFile = "nodehandler.yaml"

    path = ["../etc/nodehandler4/#{cfgFile}", "/etc/nodehandler#{MAJOR_V}/#{cfgFile}", "/etc/nodehandler/#{cfgFile}"]
    path.each {|f|
      if File.exists?(f)
        OConfig.init(f)
        return
      end
    }
    raise "Can't find #{cfgFile} in #{path.join(':')}"
  end

  private

  #
  # Create a new NodeHandler
  #
  def initialize
    initialize_oml
  end

  #
  # Initialise the OML collection scheme
  # (Note: on the verge of being Deprecated... OMLv2 should be out anytime soon)
  #
  def initialize_oml()
    #dbp = OConfig.getOmlDBSettings()
    #dbp['id'] = OmlApp.getDbName()
    #OML_EL.add_element('db', dbp)
    #mcp = OConfig.getOmlMCSettings()
  end

  #
  # This method locate the Log config file for this Node Handler
  #
  # [Return] a String with the full path to the NH config file
  #
  def findDefaultLogConfigFile()
    log = ENV['NODEHANDLER_LOG']
    if log != nil
      if ! File.exists?(log)
        raise "Can't find log file '#{log}'"
      end
      return log
    end
    logFile = "nodehandler_log.xml"
    [".#{logFile}", "~/.#{logFile}", "/etc/nodehandler#{MAJOR_V}/#{logFile}", "log/default.xml"].each {|f|
      if File.exists?(f)
        return f
      end
    }
    return nil
  end

  #
  # This method prints the experiment resource, such as an experiment, prototype,
  # or application definition to the console.
  #
  # - uri = the URI referencing the experiment resources 
  #
  def printResource(uri)
    loadGridConfigFile()
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
  # A reset message will be sent to all nodes, OML will be shut down and this
  # instance will be retired.
  #
  public
  def shutdown()
    if (! @running)
      # nothing to do
      return
    end

    @processCommands = false
    #Communicator.instance.sendReset
    if Communicator.instantiated?
      Communicator.instance.quit
    end

    OmlApp.stopCollectionServer

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
      NodeHandlerServer::stop
    rescue Exception
      #ignore
    end
    if NodeHandler.SHUTDOWN
      CMC::nodeAllOffSoft()
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
  def startWebServer()
    accLog = Logger.new("w_access")
    accLog.instance_eval {
      def << (msg)
        MObject.debug('web::access', msg.strip)
      end
    }
    begin
        NodeHandlerServer::start(@webPort, {:Logger => Logger.new("w_internal"),
             :DocumentRoot => NodeHandler.WEB_ROOT(),
             :AccessLog => [[accLog, "%h \"%r\" %s %b"]]})
    rescue Exception => except
        error("\nERROR '#{except}' when starting NH webserver !")
        error("Possible source of this Error: another NH is already running on the same tesbed...\n")
        exit
    end
  end

end 
#
# END of the NodeHandler Class Declaration


##############################################
#
# Main execution loop of the Node Handler
#
##############################################

startTime = Time.now
cleanExit = false

# Initialize the state tracking, Parse the command line options, and Run the NH
begin
  TraceState.init()
  NodeHandler.instance.parseOptions(ARGV)
  NodeHandler.instance.run
  cleanExit = true

# Process the various Exceptions...
rescue SystemExit
rescue Interrupt
  # ignore
rescue IOError => iex
  MObject.fatal('run', iex)
rescue ServiceException => sex
  begin
    MObject.fatal('run', "ServiceException: #{sex.message} : #{sex.response.body}")
  rescue Exception
  end
rescue Exception => ex
  begin
    bt = ex.backtrace.join("\n\t")
    MObject.fatal('run', "Exception: #{ex} (#{ex.class})\n\t#{bt}")
  rescue Exception
  end
end

# If NH is called in 'interactive' mode, then start a Ruby interpreter
if NodeHandler.instance.interactive?
  require 'irb'
  ARGV.clear
  ARGV << "--simple-prompt"
  ARGV << "--noinspect"
  IRB.start()
end

# End of the experimentation, Shutdown the NH
if (NodeHandler.instance.running?)
  NodeHandler.instance.shutdown
  duration = (Time.now - startTime).to_i
  MObject.info('run', "Experiment #{Experiment.ID} finished after #{duration / 60}:#{duration % 60}")
end
