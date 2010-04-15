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
# = nodeSet.rb
#
# == Description
#
# This file defines the NodeSet class 
#
require 'set'
require 'omf-common/mobject'
require 'omf-expctl/prototype'
require 'omf-expctl/node/node'
require 'omf-expctl/experiment'
require 'observer'

#
# This abstract class represents a set of nodes on which
# various operations can be performed in parallel
#
class NodeSet < MObject

  include Observable

  #
  # Return an existing NodeSet
  #
  # - groupName = the name of the group of node to return, if '*' returns 
  #               the Root NodeSet, i.e. the NodeSet with all the existing NodeSets
  #
  # [Return] an instance of an existing NodeSet
  #
  def self.[](groupName)
    if (groupName == "*")
      return NodeSet.ROOT
    end
    return @@groups[groupName]
  end

  #
  # Return the Root NodeSet, i.e. the NodeSet with all the existing NodeSets
  #
  # [Return] an instance of the NodeSet, which holds all the existing NodeSets
  #
  def self.ROOT
    return RootGroupNodeSet.instance
  end

  #
  # Return the value of the 'frozen' flag.
  #
  # [Return] true or false
  #
  def self.frozen?
    @@is_frozen
  end

  #
  # Set the value of the 'frozen' flag. When set, no changes can be done to any NodeSets.
  # Basically, this is called at the end of the resource description of an experiment, just
  # before processing the execution steps of the experiment. This prevent experimenters/operators
  # to modify the set of resources (e.g. nodes) allocated to an experiment, once its execution is
  # being staged.
  #
  def self.freeze
    @@is_frozen = true
  end

  #
  # Reset all class state. Specifically forget all node set declarations.
  # This is primarily used by the test suite.
  #
  def self.reset()
    @@groupCnt = 0
    @@groups = Hash.new
    @@execsCount = 0
    @@is_frozen = false
  end


  # Counter of anonymous groups
  @@groupCnt = 0

  # keep track of all the groups (which are named node sets)
  @@groups = Hash.new

  # Count issued commands to obtain unique ID
  @@execsCount = 0

  # Make sure that no node set are created after 'allNodes' has been used
  @@is_frozen = false

  attr_reader :groupName

  #
  # Create a new instance of NodeSet.
  # The additional 'groupName' parameter will associate a group name with this node set. 
  # All the nodes defined by the selector can from then on be addressed by 
  # the selector "/groupName/*".
  #
  # - groupName = Optional name for specific node sets
  #
  def initialize(groupName = nil)
    # for safety!
    if self.frozen?
      raise "Can't define any more nodes after 'allNodes' has been called"
    end
    @mutex = Mutex.new
    @applications = Hash.new
    @deferred = [] # store any messages if nodes aren't up yet
    @onUpBlock = nil # Block to execute for every node checking in
    @groupName = groupName != nil ? groupName.to_s : nil
    if @groupName == nil
      @groupName = "_#{@@groupCnt += 1}"
    else
      if @groupName[0] == '/'[0]
        @groupName = @groupName[1..-1]
      end
    end
    super("set::#{@groupName}") # set debug name
    if (groupName == "_ALL_")
      @nodeSelector = "*"
    else
      @nodeSelector = "#{@groupName}"
      eachNode { |n|
        n.addGroupName(@groupName)
      }
      add_observer(NodeSet.ROOT)
      @@groups[@groupName] = self
    end
    eachNode { |n|
      n.add_observer(self)
    }
  end

#  # Return the application context labeled +appId+
#  #
#  # - appId = Application context label
#  #
#  def application(id)
#    return @applications[id]
#  end
  
  #
  # This method adds an application which is associated with this node set
  # This application will be started when 'startApplications'
  # is called
  #
  # - appCtxt = the Application Context to add (AppContext). This context
  #                holds the Application name, its binding, environments,...
  #
  def addApplicationContext(appCtxt)
    @applications[appCtxt.id] = appCtxt
    eachNode { |n|
      n.addApplicationContextToStates(appCtxt)
    }
  end

  #
  # This method starts the application with ID 'name'
  # This application has to have been added with 'addApplication'
  # before.
  #
  # This method will create the command by querying the applciation's
  # definition class and obtain parameters from either the fixed settings
  # or the current value of experiment variables.
  #
  # - name = Virtual name of application
  #
  def startApplication(name)
    ctxt = @applications[name]
    raise OEDLIllegalArgumentException.new(:group, :name) unless ctxt
    ctxt.startApplication(self)
  end

  #
  # This method starts all the applications associated with this nodeSet
  #
  def startApplications()
    debug("Start all applications")
    @applications.each_key { |name|
      startApplication(name)
    }
  end

  #
  # This method stops the application with ID 'name'
  # This application has to have been added 'addApplication'
  # before.
  #
  # - name = Virtual name of application
  #
  def stopApplication(name)
    debug("Stoppping application '", name, "'")
    ctxt = @applications[name]
    if (ctxt == nil)
      raise "Unknown application '#{name}' (#{@applications.keys.join(', ')})"
    end
    exit_cmd = ECCommunicator.instance.new_command(:EXIT)
    exit_cmd.appID = name
    send(exit_cmd)
  end

  #
  # This method stops all the applications associated with this nodeSet
  #
  def stopApplications()
    debug("Stop all applications")
    @applications.each_key { |name|
      stopApplication(name)
    }
  end

  #
  # This method runs a command on all nodes within this set.
  #
  # - cmdName = the name of the executable. It should be a path if it is not
  #          in the agents search path. 
  # - args = is an optional array of arguments. If an argument starts with a '%', 
  #          each node will replace placeholders, such as %x, %y, or %n with the local values. 
  # - env = is an optional Hash of environment variables and their repsective values which will
  #          be set before the command is executed. Again, '%' substitution will occur on the values.
  # - &block = an optional block with arity 4, which will be called whenever a message is received
  #          from a node executing this command. The arguments of the block are for 
  #          'node, operation, eventName, message'.
  #
  def exec(cmdName, args = nil, env = nil, &block)
    debug("Running application '", cmdName, "'")
    procName = "exec:#{@@execsCount += 1}"
    exec_cmd = ECCommunicator.instance.new_command(:EXECUTE)
    exec_cmd.appID = procName
    exec_cmd.path = cmdName
    
    if (block.nil?)
      block = Proc.new do |node, op, eventName, message|
        prompt = "#{cmdName.split(' ')[0]}@#{node}"
        case eventName
        when 'STDOUT'
          debug "Message (from #{prompt}):  #{message}"
        when 'STARTED'
          # ignore 
        else
          debug "Event #{eventName} (from #{prompt}): #{message}"
        end
      end
    end
    # TODO: check for blocks arity.
    
    eachNode { |n|
      n.exec(procName, cmdName, args, env, &block)
    }

    # Add the environment info...
    if env != nil
      exec_cmd.env = ""
      env.each { |k,v|
        exec_cmd.env << "#{k}=#{v} "
      }
    end
    # Add the command line arguments...
    if (args != nil)
      exec_cmd.cmdLineArgs = ""
      args.each {|arg|
        if arg.kind_of?(ExperimentProperty)
          exec_cmd.cmdLineArgs << "#{arg.value} "
        else
          exec_cmd.cmdLineArgs << "#{arg.to_s} "
        end
      }
    end
    send(exec_cmd)
  end

  #
  # This method returns true if this set does not include any nodes
  #
  # [Return] true if this set is empty (no nodes associate to it)
  #
  def empty?
    flag = true
    eachNode { |n|
      flag = false
    }
    return flag
  end

  #
  # This method returns true if all nodes in this set are up
  #
  # [Return] true if all nodes in set are up
  #
  def up?
    if empty?
      return false
    end
    # This implicitly calls eachNode defined in BasicNodeSet!
    return inject(true) { |flag, n|
      #debug "Checking if #{n} is up"
      if flag
        if ! n.isEnrolled(@groupName)
          debug n, " is not enrolled in '#{@groupName}' yet."
          flag = false
        end
      end
      flag
    }
  end

  #
  # This method set the resource 'path' on all nodes in this
  # set to 'value'
  #
  # - path = Path to resource
  # - value = New value (Nil or a String or a Hash) 
  #
  def configure(path, value)
    case value.class.to_s
      when "ExperimentProperty"
        value.onChange { |v|
          configure(path, v)
        }
        valueToSend = value.value
      when "String" 
        valueToSend = value.to_s
      when "Hash"
        valueToSend = "{"
        value.each {|k,v|
          valueToSend << ":#{k} => '#{v}', " 
        }
        valueToSend << "}"
      else
        valueToSend = ""
    end
    # Notify each node to update their state trace with this Configure command
    eachNode {|n|
      n.configure(path, value)
    }
    conf_cmd = ECCommunicator.instance.new_command(:CONFIGURE)
    conf_cmd.path = path.join('/')
    conf_cmd.value = valueToSend.to_s
    send(conf_cmd)
  end

  #
  # This method executes a block of command for every node in this set
  # when it comes up. Note, we currently only support one block.
  #
  # - &block = the block of command to execute
  #
  def onNodeUp(&block)
    @onUpBlock = block
  end

  #
  # This method set link characteristics depending on tools needed.
  # - path = the full xpath used when setting the MAC filtering
  # - value = the value given to that xpath when setting it
  #
  def setLinkCharacteristics(path, value)
    theTopo = value[:topology]
    theTool = value[:method]
    theDevice = path[-2]
    # FIXME: This is a TEMPORARY hack !
    # Currently the Inventory contains only info of interfaces such as "athX"
    # This should not be the case, and should be fixed soon! When the Inventory
    # will be "clean", we will have to modify the following interface definition
    case theDevice.to_s
      when "w0"
        theInterface = "ath0"
      when "w1"
        theInterface = "ath1"
      when "e0"
        theInterface = "eth0"
      when "e1"
        theInterface = "eth1"
    end
    if theTool == "tc"
      Topology[theTopo].buildTCList(theInterface)
    else
      Topology[theTopo].buildMACBlackList(theInterface, theTool)
    end
  end

  # 
  # Send a 'SET_DISCONNECT' message to the Node Agent(s) running on the 
  # nodes/resources involved in this experiment.
  # This message will also inform the NA of: the experiment ID, the URL
  # where they can retrieve the experiment description (served by the EC
  # webserver), and the contact info for the OML collection server.
  #
  def switchDisconnectionON
    send(:SET_DISCONNECT, "#{Experiment.ID}", "#{NodeHandler.instance.expFileURL}", "#{OmlApp.getServerAddr}", "#{OmlApp.getServerPort}")
  end

  #
  # This method sets the boot image of the nodes in this nodeSet
  # If the 'setPXE' flag is 'true' (default), then the nodes in this set
  # will be configured to boot from their assigned PXE image over the network. 
  # (the name of the assigned PXE image is hold in the Inventory, the PXE service
  # is responsible for retrieving this name and setting up the network boot).
  # If the 'setPXE' flag is 'false' then the node boots from the images on their
  # local disks.
  #
  # - domain = name of the domain (testbed) of this nodeSet
  # - setPXE = true/false (default 'true') 
  #
  def pxeImage(domain = '', setPXE = true)
    if (domain == '')
      domain = "#{OConfig.domain}"
    end   
    if NodeHandler.JUST_PRINT
      if setPXE
        puts ">> PXE: Boot into network PXE image for node set #{self} in #{domain}"
      else
        puts ">> PXE: Boot from local disk for node set #{self} in #{domain}"
      end
    else
      if setPXE # set PXE
        @pxePrefix = "#{OConfig[:tb_config][:default][:pxe_url]}/setBootImageNS?domain=#{domain}&ns="
      else # clear PXE
        @pxePrefix = "#{OConfig[:tb_config][:default][:pxe_url]}/clearBootImageNS?domain=#{domain}&ns="
      end
      setPxeEnvMulti()
    end
  end

  #
  # This method sets environment for booting a node through or throughout PXE.
  # This should only be called from 'pxeImage', or any following methods
  # which may reset a node and want to restore the original environment.
  #
  # - node = the node to consider
  #
  def setPxeEnv(node)
    if (@pxePrefix != nil)
      ns = "[#{node.x},#{node.y}]"
      url = @pxePrefix + ns
      debug "PXE: #{url}"
      NodeHandler.service_call(url, "Error requesting PXE image")
    end
  end

  #
  # This method sets environment for booting multiple nodes through or
  # throughout PXE. This should only be called from 'pxeImage', or any 
  # following methods which may reset a node and want to restore the 
  # original environment.
  #
  def setPxeEnvMulti()
    if (@pxePrefix != nil)
      nsArray = []
      eachNode { |n|
          nsArray << "[#{n.x},#{n.y}]"
      }
      nset = "[#{nsArray.join(",")}]"
      url = @pxePrefix + nset
      debug "PXE: #{url}"
      NodeHandler.service_call(url, "Error requesting PXE image")
    end
  end

  #
  # This method sets the name of the image to expect on all nodes in this set
  #
  # - imageName = name of the image
  #
  def image=(imageName)
    eachNode { |n|
      n.image = imageName
    }
  end

  #
  # This method loads an image onto the disk of each node in the
  # node set. This assumed the node booted into a PXE image
  #
  # - image = Image to load onto node's disk
  # - domain = testbed for this node (optional, default= default testbed for this EC)
  # - disk = Disk drive to load (default is given by OConfig)
  #
  def loadImage(image, domain = '', disk = OConfig[:tb_config][:default][:frisbee_default_disk])
    if (domain == '')
      domain = "#{OConfig.domain}"
    end
    if NodeHandler.JUST_PRINT
      puts ">> FRISBEE: Prepare image #{image} for set #{self}"
      mcAddress = "Some_MC_address"
      mcPort = "Some_MC_port"
    else
      # get frisbeed address
      url = "#{OConfig[:tb_config][:default][:frisbee_url]}/getAddress?domain=#{domain}&img=#{image}"
      response = NodeHandler.service_call(url, "Can't get frisbee address")
      mcAddress, mcPort = response.body.split(':')
    end
    opts = {:disk => disk, :mcAddress => mcAddress, :mcPort => mcPort}
    eachNode { |n|
      n.loadImage(image, opts)
    }
    debug "Loading image #{image} from multicast #{mcAddress}::#{mcPort}"
    load_cmd = ECCommunicator.instance.new_command(:LOAD_IMAGE)
    load_cmd.address = mcAddress
    load_cmd.port = mcPort
    load_cmd.disk = disk
    send(load_cmd)
  end

  #
  # This method stops an Image Server once the image loading on each 
  # node in the nodeSet is done. 
  # This assumed the node booted into a PXE image
  #
  # - image = Image to load onto node's disk
  # - domain = testbed for this node (optional, default= default testbed for this EC)
  # - disk = Disk drive to load (default is given by OConfig)
  #
  def stopImageServer(image, domain = '', disk = OConfig[:tb_config][:default][:frisbee_default_disk])
    if (domain == '')
      domain = "#{OConfig.domain}"
    end
    if NodeHandler.JUST_PRINT
      puts ">> FRISBEE: Stop server of image #{image} for set #{self}"
    else
      # stop the frisbeed server on the Gridservice side
      debug "Stop server of image #{image} for domain #{domain}"
      url = "#{OConfig[:tb_config][:default][:frisbee_url]}/stop?domain=#{domain}&img=#{image}"
      response = NodeHandler.service_call(url, "Can't stop frisbee daemon on the GridService")
      if (response.body != "OK")
        error "Can't stop frisbee daemon on the GridService - image: '#{image}' - domain: '#{domain}'"
        error "GridService's response to stop call: '#{response.body}'"
      end
    end
  end

  def loadData(srcPath, dstPath = '/')
      # Mount the local file to a URL on our webserver
      # ALERT: Should check if +rep+ actually exists
      url_dir="/data/#{srcPath.gsub('/', '_')}"
      url="#{OMF::ExperimentController::Web.url()}#{url_dir}"
      OMF::ExperimentController::Web.mapFile(url_dir, srcPath)
      load_cmd = ECCommunicator.instance.new_command(:LOAD_DATA)
      procName = "exec:#{@@execsCount += 1}:loadData"
      load_cmd.appID = procName
      load_cmd.image = url
      load_cmd.path = dstPath
      send(load_cmd)

      block = Proc.new do |node, op, eventName, message|
          case eventName
          when 'STDOUT'
            debug "Message (from #{prompt}):  #{message}"
          when 'STARTED'
            # ignore 
          else
            debug "Event '#{eventName}' (from loadData on '#{node}'): '#{message}'"
          end
        end
      # TODO: check for blocks arity.
    
      eachNode { |n|
        n.exec(procName, 'loadData', nil, nil, &block)
      }
  end

  #
  # This method sends a command to all nodes in this nodeSet 
  #
  # - command = Command to send
  # - args = Array of parameters
  #
  def send(cmdObj)
    notQueued = true
    cmdObj.target = @nodeSelector
    @mutex.synchronize do
      if (!up?)
        debug "Deferred message ('#{@nodeSelector}') - '#{cmdObj.to_s}'" 
        @deferred << cmdObj
        notQueued = false
      end
    end
    if (up? && notQueued)
      debug "Send ('#{@nodeSelector}') - '#{cmdObj.to_s}'"
      ECCommunicator.instance.send_command(cmdObj)
      return
    end
  end

  #
  # This method is called by an observable entity (which this NodeSet is 'observing') to report some change(s)
  #
  # - sender = the entity that called this method
  # - code = the description of the change(s) to report
  #
  def update(sender, code)
    # This is a node UP or REMOVED update
    if ((code == :node_is_up) || (code == :node_is_removed))
      # Check if ALL the nodes in this NodeSet are Up
      if (up?)
        # Yes? Then mark this group as UP!
        update(self, :group_is_up)
        changed
        notify_observers(self, :group_is_up)
      end
      if @onUpBlock != nil
        begin
          @onUpBlock.call(sender)
        rescue Exception => err
          error("onUpBlock threw exception for #{sender}: #{err}")
        end
      end
    # This is a group UP update
    elsif (code == :group_is_up)
      send_deferred
    # This is a reset update
    elsif (code == :before_resetting_node)
      setPxeEnv(sender)
    end
  end

  #
  # This method sends all the deferred messages (if any) when 
  # all the nodes in this nodeSet are up
  #
  def send_deferred()
    thesize = 0
    @mutex.synchronize do
     thesize = @deferred.size
    end # synchronize
    if (thesize > 0 && up?)
      da = @deferred
      @deferred = []
      da.each { |cmdObj|
	debug "send_deferred '#{cmdObj.to_s}'"
        send(cmdObj)
      }
    end
  end

  #
  # Return a String text describing this NodeSet
  #
  def to_s
    @nodeSelector
  end
end
