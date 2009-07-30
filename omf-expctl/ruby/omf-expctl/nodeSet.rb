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
# This file defines the NodeSet class and its sub-classes: BasicNodeSet, AbstractGroupNodeSet,
# GroupNodeSet, and RootGroupNodeSet.
# This file also defines the NodeSetPath class and its sub-class RootNodeSetPath 
#
#
require 'set'
require 'omf-common/mobject'
require 'omf-expctl/prototype'
require 'omf-expctl/node'
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
  def NodeSet.[](groupName)
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
  def NodeSet.ROOT
    return RootGroupNodeSet.instance
  end

  #
  # Return the value of the 'frozen' flag.
  #
  # [Return] true or false
  #
  def NodeSet.frozen?
    @@is_frozen
  end

  #
  # Set the value of the 'frozen' flag. When set, no changes can be done to any NodeSets.
  # Basically, this is called at the end of the resource description of an experiment, just
  # before processing the execution steps of the experiment. This prevent experimenters/operators
  # to modify the set of resources (e.g. nodes) allocated to an experiment, once its execution is
  # being staged.
  #
  def NodeSet.freeze
    @@is_frozen = true
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

  #
  # This method adds an application which is associated with this node set
  # These applications will be started when 'startApplications'
  # is called
  #
  # - app = Application to register
  # - vName = Virtual name used for this app (used for state name)
  # - bindings = Bindings for local parameters
  # - env = Environment to set before starting application
  # - install = Request installation immediately
  #
  def addApplication(app, vName, bindings, env, install = true)
    vName = vName.to_s
    @applications[vName] = {
      :app => app,
      :bindings => bindings,
      :env => env
    }
    if install
      # Immediately request installation
      appDef = app.appDefinition
      if (aptName = appDef.aptName) != nil
        # Install App from DEB package using apt-get 
        send(:APT_INSTALL, "app:#{vName}/install", aptName)
      elsif (rep = appDef.binaryRepository) != nil
        # Install App from TAR archive using wget + tar 
        # We first have to mount the local TAR file to a URL on our webserver
        url_dir="/install/#{rep.gsub('/', '_')}"
        url="#{OMF::ExperimentController::Web.url()}#{url_dir}"
        OMF::ExperimentController::Web.mapFile(url_dir, rep)
        send(:PM_INSTALL, "app:#{vName}/install", url, '/')
      end
    end
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
    debug("Starting application '", name, "'")
    ctxt = @applications[name]
    if (ctxt == nil)
      raise "Unknown application '#{name}' (#{@applications.keys.join(', ')})"
    end

    app = ctxt[:app]
    bindings = ctxt[:bindings]
    env = ctxt[:env]
    appDef = app.appDefinition
    procName = "app:#{name}"
    cmd = [procName, 'env', '-i']
    if (env != nil)
      env.each {|name, value|
        cmd << "#{name}=#{value}"
      }
    end

    cmd << appDef.path
    pdef = appDef.properties
    # check if bindings contain unknown parameters
    if (bindings != nil)
      if (diff = bindings.keys - pdef.keys) != []
        raise "Unknown parameters '#{diff.join(', ')}'" \
          + " not in '#{pdef.keys.join(', ')}'."
      end
      cmd = appDef.getCommandLineArgs(procName, bindings, self, cmd)
    end
    send(:exec, *cmd)
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
    procName = "app:#{name}"
    send(:STDIN, procName, 'exit')
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
    cmd = [procName]

    if (env != nil)
      cmd += ['env', '-i']
      env.each {|name, value|
        cmd << "#{name}=#{value}"
      }
    end
    cmd << cmdName
    
    if (args != nil)
      args.each {|arg|
        if arg.kind_of?(ExperimentProperty)
          cmd << arg.value
        else
          cmd << arg.to_s
        end
      }
    end
    send(:exec, *cmd)
  end

  #
  # This method returns true if all nodes in this set are up
  #
  # [Return] true if all nodes in set are up
  #
  def up?
    return inject(true) { |flag, n|
      #debug "Checking if #{n} is up"
      if flag
        if ! n.isUp
          debug n, " is not up yet."
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
    send(:CONFIGURE, path.join('/'), valueToSend.to_s)
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
  # This method builds and activates the MAC address blacklists (if any)
  # on all the nodes in this NodeSet
  #
  # - path = the full xpath used when setting the MAC filtering
  # - value = the value given to that xpath when setting it
  #
  def setMACFilteringTable(path, value)
    theTopo = value[:topology]
    theTool = value[:method]
    theDevice = path[-2]
    # FIXME: This is a TEMPORARY hack !
    # Currently the Inventory contains only info of interfaces such as "athX"
    # This should not be the case, and should be fixed soon! When the Inventory
    # will be "clean", we will have to modify the following interface definition
    if theDevice.to_s == "w0"
      theInterface = "ath0"
    else
      theInterface = "ath1"
    end
    Topology[theTopo].buildMACBlackList(theInterface, theTool)
  end

  # 
  # Send a 'SET_DISCONNECT' message to the Node Agent(s) running on the 
  # nodes/resources involved in this experiment.
  # This message will also inform the NA of: the experiment ID, the URL
  # where they can retrieve the experiment description (served by the NH
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
      domain = "#{OConfig.GRID_NAME}"
    end   
    if NodeHandler.JUST_PRINT
      if setPXE
        puts ">> PXE: Boot into network PXE image for node set #{self} in #{domain}"
      else
        puts ">> PXE: Boot from local disk for node set #{self} in #{domain}"
      end
    else
      if setPXE # set PXE
        @pxePrefix = "#{OConfig.PXE_SERVICE}/setBootImageNS?domain=#{domain}&ns="
      else # clear PXE
        @pxePrefix = "#{OConfig.PXE_SERVICE}/clearBootImageNS?domain=#{domain}&ns="
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
      node.image = "pxe:image"
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
      eachNode { |n|
        n.image = "pxe:image"
      }
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
  # - domain = testbed for this node (optional, default= default testbed for this NH)
  # - disk = Disk drive to load (default is given by OConfig.DEFAULT_DISK)
  #
  def loadImage(image, domain = '', disk = OConfig.DEFAULT_DISK)
    if (domain == '')
      domain = "#{OConfig.GRID_NAME}"
    end
    if NodeHandler.JUST_PRINT
      puts ">> FRISBEE: Prepare image #{image} for set #{self}"
      mcAddress = "Some_MC_address"
      mcPort = "Some_MC_port"
    else
      # get frisbeed address
      url = "#{OConfig.FRISBEE_SERVICE}/getAddress?domain=#{domain}&img=#{image}"
      response = NodeHandler.service_call(url, "Can't get frisbee address")
      mcAddress, mcPort = response.body.split(':')
    end
    opts = {:disk => disk, :mcAddress => mcAddress, :mcPort => mcPort}
    eachNode { |n|
      n.loadImage(image, opts)
    }
    debug "Loading image #{image} from multicast #{mcAddress}::#{mcPort}"
    send('LOAD_IMAGE', mcAddress, mcPort, disk)
  end

  #
  # This method stops an Image Server once the image loading on each 
  # node in the nodeSet is done. 
  # This assumed the node booted into a PXE image
  #
  # - image = Image to load onto node's disk
  # - domain = testbed for this node (optional, default= default testbed for this NH)
  # - disk = Disk drive to load (default is given by OConfig.DEFAULT_DISK)
  #
  def stopImageServer(image, domain = '', disk = OConfig.DEFAULT_DISK)
    if (domain == '')
      domain = "#{OConfig.GRID_NAME}"
    end
    if NodeHandler.JUST_PRINT
      puts ">> FRISBEE: Stop server of image #{image} for set #{self}"
    else
      # stop the frisbeed server on the Gridservice side
      debug "Stop server of image #{image} for domain #{domain}"
      url = "#{OConfig.FRISBEE_SERVICE}/stop?domain=#{domain}&img=#{image}"
      response = NodeHandler.service_call(url, "Can't stop frisbee daemon on the GridService")
      if (response.body != "OK")
        error "Can't stop frisbee daemon on the GridService - image: '#{image}' - domain: '#{domain}'"
        error "GridService's response to stop call: '#{response.body}'"
      end
    end
  end

  #
  # This method sends a command to all nodes in this nodeSet 
  #
  # - command = Command to send
  # - args = Array of parameters
  #
  def send(command, *args)
    debug("#send: args(#{args.length})'#{args.join('#')}")
    notQueued = true
    @mutex.synchronize do
      if (!up?)
        debug "Deferred message: #{command} #{@nodeSelector} #{args.join(' ')}"
        @deferred << [command, args]
        notQueued = false
      end
    end
    if (up? && notQueued)
      NodeHandler.instance.communicator.send(@nodeSelector, command, args)
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
    #debug "nodeSet (#{to_s}) update: #{sender} #{code}"
    if ((code == :node_is_up) || (code == :node_is_removed))
      if (up?)
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
    elsif (code == :group_is_up)
      send_deferred
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
      da.each { |e|
        command = e[0]
        args = e[1]
        debug "send_deferred(#{args.class}:#{args.length}):#{args.join('#')}"
        send(command, *args)
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


#
# This sub-class of NodeSet represents a set of individual nodes.
#
class BasicNodeSet < NodeSet

  #
  # This method creates a new node set where the selector is a Topology object
  #
  # - groupName = optional name for specific node sets, see NodeSet's constructor.
  # - topo = optional, when defined all nodes in the given topology will be added to this NodeSet
  #
  def initialize(groupName, topo = nil)
    @topo = topo
    super(groupName)
  end

  #
  # This method adds an application which is associated with this NodeSet
  # These applications will be started when 'startApplications'
  # is called. See NodeSet::addApplication for argument details
  #
  def addApplication(app, vName, bindings, env, install = true)
    super(app, vName, bindings, env, install)
    self.eachNode { |n|
      n.addApplication(app, vName, bindings, env)
    }
  end

  #
  # This method executes a block of commands for every node in this NodeSet
  #
  # - &block = the block of command to execute
  #
  def eachNode(&block)
    @topo.eachNode(&block) if !@topo.nil?
  end

  #
  # This method calls inject over the nodes contained in this NodeSet.
  #
  # - seed = the initial value for the inject 'result'
  # - &block = the block of command to inject
  #
  def inject(seed = nil, &block)
    @topo.inject(seed, &block) if !@topo.nil?
  end

  #
  # This method powers ON all the nodes in this NodeSet
  #
  def powerOn()
    ns = @topo.nodeSetDecl
    # Check that NH is NOT in 'Slave Mode' - If so call CMC to switch node(s) ON
    if !NodeHandler.SLAVE_MODE()
      CMC.nodeSetOn(ns)
    end
    eachNode { |n|
      n.powerOn()
      if NodeHandler.JUST_PRINT
        n.checkIn(n.nodeId, '1.0', 'UNKNOWN')
        n.heartbeat(0, 0, Time.now.to_s)
      end
    }
  end

  #
  # This method powers OFF all nodes in this set 
  # By default the nodes are being powered off softly (asked nicely to 
  # powerdown), but setting 'hard' to true the nodes are being powered 
  # off immediately. Use the hard power down with caution.
  #
  # - hard = true/false (optional, default=false)
  #
  def powerOff(hard = false)
    ns = @topo.nodeSetDecl
    if hard
      CMC.nodeSetOffHard(ns)
    else
      CMC.nodeSetOffSoft(ns)
    end
    eachNode { |n| n.powerOff() }
  end

end


#
# This abstract class implements behavior for a NodeSet, which contains other NodeSets. 
# Basically this class implements a the abstract idea of a 'group of NodeSets'.
#
class AbstractGroupNodeSet < NodeSet

  #
  # This method starts all the applications associated to all the
  # NodeSets in this group
  #
  def startApplications
    debug("Start all applications")
    super
    eachGroup { |g|
      debug("..... Start applications in #{g}")
      g.startApplications
    }
  end

  #
  # This method stops all the applications associated to all the
  # NodeSets in this group
  #
  def stopApplications
    debug("Stop all applications")
    super
    eachGroup { |g|
      debug(".... Stop applications in #{g}")
      g.stopApplications
    }
  end

  #
  # This method powers ON all nodes in all the NodeSets in this group
  #
  def powerOn()
    eachGroup { |g|
      g.powerOn
    }
  end

  #
  # This method powers OFF all nodes in all the NodeSets in this group
  # By default the nodes are being powered off softly (asked nicely to 
  # powerdown), but setting 'hard' to true the nodes are being powered 
  # off immediately. Use the hard power down with caution.
  #
  # - hard = true/false (optional, default=false)
  #
  def powerOff(hard = false)
    eachGroup { |g|
      g.powerOff(hard)
    }
  end

end


#
# This class implements a Group of NodeSets.
# It is the usuable sub-class of AbstractGroupNodeSet
#
class GroupNodeSet < AbstractGroupNodeSet

  #
  # This method creates a new group NodeSet, where the selector is an
  # array of names of existing node sets.
  #
  # - groupName = optional name for this group of NodeSet 
  # - selector = expression that identifies the nodes in this group of NodeSets
  #
  def initialize(groupName, selector)
    if (selector == nil)
      raise "Need to specifiy array of nodes"
    end
    @nodeSets = Set.new
    add(selector)
    super(groupName)
  end

  #
  # This method executes a block of commands for every NodeSet in this group of NodeSets
  #
  # - &block = the block of command to execute
  #
  def eachGroup(&block)
    debug("Running 'eachGroup' in GroupNodeSet")
    @nodeSets.each { |g|
       block.call(g)
    }
  end

  #
  # This method adds an application which is associated with every NodeSets in this group
  # This application will be started when 'startApplications'
  # is called. See NodeSet::addApplication for argument details
  #
  def addApplication(app, vName, bindings, env, install = true)
    super(app, vName, bindings, env, install)
    # inform all nodes of enclosed groups, so they will add this app to their state
    eachNode { |n|
      n.addApplication(app, vName, bindings, env)
    }
  end

  #
  # This method executes a block of commands for every node in every NodeSets in this group of NodeSets
  #
  # - &block = the block of command to execute
  #
  def eachNode(&block)
    @nodeSets.each { |s|
      s.eachNode &block
    }
  end

  #
  # This method calls inject over the NodeSets contained in this group.
  #
  # - seed = the initial value for the inject 'result'
  # - &block = the block of command to inject
  #
  def inject(seed = nil, &block)
    result = seed
    @nodeSets.each { |s|
      result = s.inject(result, &block)
    }
    return result
  end

  private

  #
  # This method adds the nodes described by 'selector' as a new NodeSet in this group of NodeSets
  #
  # - selector = an Array describing the new NodeSet to add to this group, it should be of the
  #              form [[a, b], [c..d, f]]
  # 
  def add(selector)
    if selector.kind_of?(Array)
      # now lets check if the array just describes a single
      # node [x, y] a set of nodes [[a, b], [c..d, f]]
      selector.each { |name|
        s = NodeSet[name]
        if s == nil
          raise "Unknown set name '#{name}'"
        end
        s.add_observer(self)
        @nodeSets.add(s)
      }
    elsif selector.kind_of?(ExperimentProperty)
      s = selector.value
      add(s)
    else
       raise "Unrecognized node set selector type '#{selector.class}'."
    end
  end
end

#
# This singleton class represents ALL nodes. 
# It is a group of NodeSets, which contains ALL the NodeSets
#
class RootGroupNodeSet < AbstractGroupNodeSet
  include Singleton

  #
  # This method creates this singleton 
  #
  def initialize()
    super('_ALL_')
    @nodeSelector = "*"
  end

  #
  # This method executes a block of command on ALL the groups of NodeSets
  #
  # - &block = the block of command to execute
  #
  def eachGroup(&block)
    debug("Running 'eachGroup' in RootGroupNodeSet")
    @@groups.each_value { |g|
      if g.kind_of?(BasicNodeSet)
        debug("Call #{g}")
        block.call(g)
      end
    }
  end

  #
  # This method executes a block of command on ALL the node in ALL the groups of NodeSets
  #
  # - &block = the block of command to execute
  #
  def eachNode(&block)
    #debug("Running 'each' in RootGroupNodeSet")
    @@groups.each_value { |g|
      if g.kind_of?(BasicNodeSet)
        debug("Running each for #{g}")
        g.eachNode &block
      end
    }
  end

  #
  # This method calls inject over ALL the nodes 
  #
  # - seed = the initial value for the inject 'result'
  # - &block = the block of command to inject
  #
  def inject(seed = nil, &block)
    result = seed
    @@groups.each_value { |g|
      #debug "#inject: Checking #{g}:#{g.class} (#{result})"
      if g.kind_of?(BasicNodeSet)
        #debug "#inject: Calling inject on #{g} (#{result})"
        result = g.inject(result, &block)
      end
      #debug "#inject: result: #{result}"
    }
    return result
  end

  #
  # This method powers OFF ALL the nodes
  # By default the nodes are being powered off softly (asked nicely to 
  # powerdown), but setting 'hard' to true the nodes are being powered 
  # off immediately. Use the hard power down with caution.
  #
  # - hard = true/false (optional, default=false)
  #
  def powerOff(hard = false)
    if hard
      CMC.nodeAllOffHard()
    else
      CMC.nodeAllOffSoft()
    end
    Node.each {|n|
      n.powerOff()
    }
  end

end

#
# This singleton Class represents ALL nodes that are part of a 
# defined NodeSet Group
#
class DefinedGroupNodeSet < RootGroupNodeSet 
  def initialize()
    super()
    sel = ""
    eachGroup {|g| sel = sel + "#{g.to_s} " }
    @nodeSelector = "\"#{sel}\""
  end
end

###########################################################################
# NOTE: Should the following Path classes be moved to a separate file?
###########################################################################

#
# This class defines a 'PATH' to access/set attributes of a given NodeSet
#
class NodeSetPath < MObject
  attr_reader :nodeSet, :path

  # List of valid 'PATHS' for a NodeSet
  VALID_PATHS_WITH_VALUES = {
    "mode=" => %r{net/[ew][01]},
    "type=" => %r{net/[ew][01]},
    "rts=" => %r{net/[ew][01]},
    "rate=" => %r{net/[ew][01]},
    "essid=" => %r{net/[ew][01]},
    "ip=" => %r{net/[ew][01]},
    "channel=" => %r{net/[ew][01]},
    "tx_power=" => %r{net/[ew][01]},
    "netmask=" => %r{net/[ew][01]},
    "mac=" => %r{net/[ew][01]},
    "mtu=" => %r{net/[ew][01]},
    "arp=" => %r{net/[ew][01]},
    "enforce_link=" => %r{net/[ew][01]},
    "route" => %r{net/[ew][01]},
    "filter" => %r{net/[ew][01]},
    "net" => //
  }
  VALID_PATHS_WITHOUT_VALUES = {
    "down" => %r{net/[ew][01]},
    "up" => %r{net/[ew][01]},
  }
  VALID_PATHS = VALID_PATHS_WITH_VALUES.merge(VALID_PATHS_WITHOUT_VALUES)
  VALID_PATHS_RE = {
    /[ew][01]/ => /net/
  }

  #
  # Create a new Path (i.e. NodeSetPath instance) for a given NodeSet, or from an already existing Path
  #
  # - obj = a NodeSet or NodeSetPath instance for/from which to create this new instance
  # - newLeaf = optional, add a new leaf to the NodeSetPath (default= nil)
  # - value = optional, set a value to this NodeSetPath (default= nil)
  # - block = optional, a block of command to execute (default= nil)
  #
  def initialize(obj, newLeaf = nil, value = nil, block = nil)
    if obj.kind_of? NodeSetPath
      @nodeSet = obj.nodeSet
      @path = obj.path.clone
    elsif obj.kind_of? NodeSet
      @nodeSet = obj
      @path = Array.new
    else
      raise "Argument needs to be either a NodeSet, or a NodeSetPath, but is #{obj.class.to_s}"
    end

    if value != nil
      #if newLeaf == nil || newLeaf[-1] != ?= 
      if newLeaf == nil 
        path = ""
        @path.each {|p| path = path + '/' +p.to_s}
        raise "Missing assignment operator or argument for path '#{path}/#{newLeaf}'."
        # NOTE: cannot call 'pathString' here cause @pathSubString has not been set yet!
      end
      if newLeaf[-1] != ?=
        newLeaf = newLeaf[0 .. -1]
      else
        newLeaf = newLeaf[0 .. -2]
      end
      @value = value
    end
    if newLeaf != nil
      @path += [newLeaf]
    end

    @pathSubString = @path.join('/')
    super(@pathSubString == "" ? "nodeSetPath" : "nodeSetPath::#{@pathSubString}")
    #debug("Create nodeSetPath '", pathString, "' obj: #{obj.class}")

    if block != nil
      call &block
    end
    if value != nil
      if (@path.last.to_s == "enforce_link")
        @nodeSet.setMACFilteringTable(@path, @value)
        # If this NH is invoked with support for temporary disconnected node/resource, then 
        # do not execute any node/resource configuration commands (this will be done by the
        # slave NH running on the node/resource).
      elsif (NodeHandler.disconnectionMode? == false) 
        @nodeSet.configure(@path, @value)
      end
    # If the path is one that does not require a value (e.g. ip.down or ip.up)
    # then we send a configure command to the nodes
    elsif VALID_PATHS_WITHOUT_VALUES.has_key?(@path.last.to_s)
        @nodeSet.configure(@path, @value)
    end
  end

  #
  # This method calls a block of commands.
  # If the block's arity is 1, this method passes this NodeSetPath instance as the argument to the block.
  # If the block's arity is >1, this method raises an error.
  #
  # - &block = a block of commands
  #
  def call(&block)
    case block.arity
      when -1, 0
        block.call()
      when 1
        block.call(self)
      else
        raise "Block (#{block.arity}) for '" + pathString + "' requires zero, or one argument (|n|)"
    end
  end

  #
  # This method returns the String corresponding to this Path
  #
  # [Return] a String corresponding to this Path
  #
  def pathString()
    @nodeSet.to_s + '/' + @pathSubString
  end

  #
  # This method parses a String describing a sub-Path to this Path, and create a new corresponding NodeSetPath instance.
  # Note: We make use of Ruby's 'method_missing' feature to parse 'x.y.z' into a NodeSetPath 
  #
  # - name = string with the sub-Path to parse
  # - *args = argument given as value to this Path (always 0 or 1 argument, an error is raised if more arguments) 
  # - &block = optional, a block of commands to pass on to the new NodeSetPath instance 
  #
  # [Return] a new NodeSetPath instance corresponding to the parsed String
  #
  def method_missing(name, *args, &block)
    # puts "path(" + pathString + ") " + name.to_s + " @ " + args.to_s + " @ " + (block != nil ? block : nil).to_s
    if args.length > 1
      raise "Assignment to '" + pathString + "/" + name.to_s + "' can only be a single parameter."
    end
    name_s = name.to_s
    re = VALID_PATHS[name_s]
    debug("Testing '#{name}' => '#{@pathSubString}' : #{re}")
    if (re != nil)
      debug("Checking against '#{re}'")
      if (@pathSubString =~ re) != 0
        warn("Unrecognized path '#{@pathSubString}/#{name}'")
      end
    else
      found = false
      VALID_PATHS_RE.each { |nameRe, pattern|
        if (name_s =~ nameRe) == 0
          found = true
          if (@pathSubString =~ pattern) != 0
            warn("Unrecognized path '#{@pathSubString}/#{name}'")
          end
        end
      }
      if ! found
        warn("Unrecognized path '#{@pathSubString}/#{name}'")
      end
    end
    #debug("Creating new nodeSetPath '#{name}'")
    return NodeSetPath.new(self, name_s, args[0], block)
  end

  # 
  #  Set the Flag indicating that this Experiment Controller (NH) is invoked for an 
  #  Experiment that support temporary disconnections
  #       
  def allowDisconnection
    # Check if NH is NOT in 'Slave Mode'
    # When is 'Slave Mode' this mean there is already a Master NH which has its 'disconnection mode' set
    # so we do nothing here
    if !NodeHandler.SLAVE_MODE()
      NodeHandler.setDisconnectionMode()
      @nodeSet.switchDisconnectionON
    end 
  end

end


#
# This class defines the Root Path, i.e. the Root NodeSetPath.
# A Root Path has additional methods specific to configuring the NodeSet itself
#
class RootNodeSetPath < NodeSetPath

  #
  # Add a new Prototype to the NodeSet associated with this Root Path
  #
  # - name = name of the Prototype to associate with the NodeSet of this Path
  # - params = optional, a Hash with the bindings to be passed on to the Prototype instance (see Prototype.instantiate)
  #
  def prototype(name, params = nil)
    debug "Use prototype #{name}."
    p = Prototype[name]
    if (p == nil)
      error("Unknown prototype '#{name}'")
      return
    end
    p.instantiate(@nodeSet, params)
  end
  
  #
  # Add a new Application to the NodeSet associated with this Root Path
  #
  # - app = Application to register
  # - vName = Virtual name used for this app (used for state name)
  # - bindings = Bindings for local parameters
  # - env = Environment to set before starting application
  # - install = Request installation immediately
  #
  def addApplication(app, vName, bindings, env, install = true)
    if app.kind_of? String
      # if this is a one-off command line application
      # then create a default Application object to hold it
      debug "Implicit creation of an app instance from: #{app}"
      appInstance =  Application.new(app,vName)
    else
      # real NH-compatible application (i.e. ruby wrapper)
      appInstance = app
    end
    @nodeSet.addApplication(appInstance, vName, bindings, env, install)
  end

  #
  # Trigger boot from PXE Image for the nodes in the NodeSet associated to this Root Path
  #
  # - image = PXE image to boot from. If 'image' is non-nil, then the nodes in the NodeSet will 
  #           be configured to boot from that PXE image name over the network. If 'image' is set 
  #           to 'nil' then the nodes will boot from their local disks. 
  # - imageName = optional, name of image to check for. This optional name allows a node to verify 
  #           at the time the nodes check in (i.e. after boot and NA-NH contact), if it really booted 
  #           into the right image. The image name is stored in '/.orbit_image'
  #
  def pxeImage(domain, pxeFlag)
    @nodeSet.pxeImage(domain, pxeFlag)
    #@nodeSet.pxeImage(image, imageName, domain)
  end

  #
  # Set the disk image to boot the nodes in the NodeSet associated to this Root Path.
  #
  # - image = Image to boot from. If it is set to 'nil' then the nodes boot from their local disks.
  #
  def image=(image)
    @nodeSet.image = image
  end

  #
  # Load an image onto the disk of each node in the NodeSet associated with this Root Path.
  # This assumed that the nodes previously booted via PXE over the network.
  #
  # - image = name of the disk image to load onto the nodes 
  # - domain = name of the domain of the nodes 
  #
  def loadImage(image, domain)
    @nodeSet.loadImage(image, domain)
  end
  
  #
  # Stop an Image Server after loading an image onto the disks of each node in the NodeSet of this Root Path. 
  # This assumed that the nodes previously booted via PXE over the network.
  #
  # - image = name of the disk image that was loaded onto the nodes 
  # - domain = name of the domain of the nodes 
  #
  def stopImageServer(image, domain)
    @nodeSet.stopImageServer(image, domain)
  end

  #
  # When every nodes in the NodeSet associated to this Root Path are in 'UP' state, 
  # then Execute a block of commands for everyone of them 
  #
  # - &block = the block of commands to execute
  #
  def onNodeUp(&block)
    @nodeSet.onNodeUp &block
  end

  #
  # Execute a block of commands for every nodes in the NodeSet associated to this Root Path.
  #
  # - &block = the block of commands to execute
  #
  def eachNode(&block)
    @nodeSet.eachNode(&block)
  end

  #
  # This method calls inject over the nodes contained in the NodeSet associated to this Root Path.
  #
  # - seed = the initial value for the inject 'result'
  # - &block = the block of command to inject
  #
  def inject(seed = nil, &block)
    @nodeSet.inject(seed, &block)
  end

  #
  # This method starts all Applications associated to the nodes in the NodeSet of this Root Path.
  #
  def startApplications()
    debug("Start all applications")
    @nodeSet.startApplications
  end

  #
  # This method start a given Application associated to the nodes in the NodeSet of this Root Path.
  #
  # - name = name of the Application to start
  #
  def startApplication(name)
    @nodeSet.startApplication(name)
  end

  #
  # This method stops all Applications associated to the nodes in the NodeSet of this Root Path.
  #
  def stopApplications()
    debug("Stop all applications")
    @nodeSet.stopApplications
  end

  #
  # This method stops a given Application associated to the nodes in the NodeSet of this Root Path.
  #
  # - name = name of the Application to stop
  #
  def stopApplication(name)
    @nodeSet.stopApplication(name)
  end

  #
  # This method sends a message on the STDIN of a given application, which is 
  # running on the nodes in the NodeSet of this Root Path.
  #
  # - name = the name of the application to send the message to 
  # - *args = a sequence of arguments to send as a messages to this application
  #
  def sendMessage(name, *args)
    @nodeSet.send(:STDIN, "app:#{name}", *args)
  end
  
  #
  # This method powers ON all nodes in the NodeSet of this Root Path.
  #
  def powerOn()
    @nodeSet.powerOn
  end

  #
  # This method powers OFF all nodes in the NodeSet of this Root Path.
  # By default the nodes are being powered off softly (asked nicely to 
  # powerdown), but setting 'hard' to true the nodes are being powered 
  # off immediately. Use the hard power down with caution.
  #
  # - hard = optional, default false
  #
  def powerOff(hard = false)
    @nodeSet.powerOff(hard)
  end

  #
  # This method runs a command on all nodes in the NodeSet of this Root Path.
  #
  # - cmdName = name of the executable to run. It should be a full OS path, unless it is
  #             in the default path of the Node Agents running on the nodes.
  # - args = an optional array of arguments. If an argument starts with a '%', each node 
  #             will replace placeholders such as %x, %y, or %n with their own local values. 
  # - env = an optional Hash of environment variables and their respective values. This will
  #             be set before the command is executed. Again, '%' substitution will occur
  #             on these values.
  # - &block = an optional block of commands with arity 4, which will be called whenever a 
  #             message is received from a node executing 'cmdName'. The arguments for this block 
  #             are |node, operation, eventName, message|.
  #
  def exec(cmdName, args = nil, env = nil, &block)
    @nodeSet.exec(cmdName, args, env, &block)
  end

  #
  # Return true if all nodes in the NodeSet of this Root Path are in 'UP' state.
  #
  # [Return] true or false
  #
  def up?()
    @nodeSet.up?
  end

  #
  # Return a String describing the NodeSet associated to this Root Path
  #
  # [Return] a String
  #
  def to_s
    if NodeHandler.interactive?
      @nodeSet.to_s
    else
      super()
    end
  end
end

#####################################
#
# Testing Code
#
# Create _ALL_ group
#RootGroupNodeSet.new()
if $0 == __FILE__
  MObject.initLog 'test'
#  n = NodeSet.new([1, 2..3])
#  n = NodeSet.new([1..2, 2..3])
#  n = NodeSet.new([[1..2, 2..3], [6..8, 5]])
  n = NodeSet.new([[2, 1..3], [3, [1, 3]]])
end
