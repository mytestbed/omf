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
# = node.rb
#
# == Description
#
# This file defines the 'Node' class
#
#
require 'omf-common/mobject'
require 'omf-expctl/prototype'
require 'rexml/document'
require 'rexml/element'
require 'rexml/xpath'
require 'omf-common/arrayMD'
require 'omf-common/servicecall'
require 'observer'
require 'date'

#
# This class defines an experimental Node on the testbed
#
class Node < MObject
  include Observable

  W0_IF = "eth2"
  W_ADHOC = "ad-hoc"

  STATUS_DOWN = 'DOWN'
  STATUS_POWERED_ON = 'POWERED_ON'
  STATUS_POWERED_OFF = 'POWERED_OFF'
  STATUS_POWERED_RESET= 'POWERED_RESET'
  STATUS_CHECKED_IN = 'CHECKED_IN'
  STATUS_UP = 'UP'
  STATUS_RESET = 'RESET'
  STATUS_AGENT_RESET = 'AGENT_RESET'
  REBOOT_TIME = 8 # in sec
  

  @@nodes = Hash.new
  #@@nodes = ArrayMD.new

  #
  # Return the node at location 'x'@'y'. If no node exists, return nil.
  # - x = x coordinate of the node to return
  # - y = y coordinate of the node to return
  #
  # [Return] a Node object or 'nil' if no node exits at that location
  #
  def Node.[] (name)
    #n = @@nodes[x][y]
    ## take care of ArrayMD elements
    #return n.kind_of?(Node) ? n : nil
    return @@nodes[name]
  end

  #
  # Return the node called "name". If no node exists, create a new one.
  #  name - node name
  #
  # [Return] an existing or a new Node object 
  #
  def Node.at! (name)
    n = @@nodes[name.to_s]
    if !n.kind_of?(Node)
      #
      # Checking the CMC for active node might not be useful anymore, as we
      # already wait for nodes to 'enroll', i.e. inactive Nodes will never
      # enroll and thus will be excluded of the experiment after the enroll
      # timeout. Furthermore, we will in the future use a more dynamic way
      # of checking for active nodes (eg. sending a request directly to the
      # node's pubsub, and waiting for replies from node itself or AM).
      #
      #if CMC::nodeActive?(name)
      #  n = Node.new(name)
      #else
      #  raise ResourceException.new("Node #{name} is NOT active")
      #end

      resources = NodeHandler.RESOURCES
      if resources.include?(name)
        n = Node.new(name)
      else
        raise ResourceException.new("Resource '#{name}' could not be found in the current slice!")
      end
    end
    return n
  end

  #
  # Return an array of nodes matching the 'xpathExpr'
  #
  # - xpathExpr = the XPath defining the nodes to return
  #
  # [Return] an Array of Node objects
  #
  def Node.match(xpathExpr)
    m = REXML::XPath.match(NodeHandler::ROOT_EL, "nodes/#{xpathExpr}")
    nodes = Set.new
    m.each { |ne|
      if ne.kind_of?(NodeElement)
        nodes.add(ne.node)
      end
    }
    return nodes.to_a
  end

  #
  # Execute a code-block for every created node
  # 
  # - &block = the code-block to execute
  #
  def Node.each(&block)
    #@@nodes.each(&block)
    @@nodes.each_value(&block)
  end

  #
  # Check if all nodes in this experiment are now reconnected to the 
  # Experiment Controller (aka 'Node Handler'). This is only useful, when 
  # running an experiment which allow nodes/resources to be temporary 
  # disconnected
  #
  # [Return] true/false
  #
  def Node.all_reconnected?
    Node.each { |n|
      return false if !n.reconnected
    }
    return true
  end

  # True if node is up, false otherwise
  #attr_reader :isUp

  # A set listing all the group memberships for this node
  attr_reader :groupMembership

  # ID of shadow xml node
  attr_reader :nodeID
  
  # Name of image to expect on node
  attr_reader :image

  # Time the node was powered up
  attr_reader :poweredAt

  # Time the node checked in
  attr_reader :checkedInAt

  #
  attr_accessor :reconnected

  public :to_s

  #
  # Return true is this node is in the UP state
  #
  # [Return] true/false
  #
  def isUp
    return (@nodeStatus == STATUS_UP)
  end

  def isEnrolled(group)
    if @groups.has_key?(group)
      return @groups[group]
    else
      error "Node '#{@nodeID}' does not belong to group '#{group}'"
      return false
    end
  end

  #
  # Add an application to the states of this Node
  #
  # - appCtxt = the Application Context to add (AppContext). This context
  #                holds the Application name, its binding, environments,...
  #
  def addApplicationContextToStates(appCtxt)
    debug("Add application #{appCtxt.id} to #{self}")
    TraceState.nodeAddApplication(self, appCtxt)
  end

  #
  # A command will be executed on the Node. Call the block
  # whenever an event arrives for this command.
  #
  # - procName = name of the Application
  # - cmdName = Command's name
  # - args = arguments for the command
  # - env = environment for the command
  # - &block = code-block to execute
  #
  def exec(procName, cmdName, args, env, &block)
    @execs[procName] = block
  end

  #
  # A device on this Node produced an event, log it as an INFO message
  #
  # - eventName = Name of event
  # - devName = Name of device
  # - message = Explanatory message
  #
  def onDevEvent(eventName, devName, message)
    info("Device '#{devName}' reported #{message}")
  end

  #
  # An appliciation on this Node produced an event, log it and execute the 
  # corresponding code-block, if any.
  #
  # - eventName = Name of event
  # - appId = Logical name of app
  # - message = Explanatory message
  #
  def onAppEvent(eventName, appId, message)
    appName, op = appId.split('/')
    if NodeHandler.SHOW_APP_OUTPUT &&
       ((eventName.upcase == "STDOUT") || (eventName.upcase == "STDERR")) 
       # When requested by user, print SDOUT events on our own standard-out
       info("Output of app '#{appId}' -> '#{message}'")
    end
    if (appName =~ /^exec:/)
      if ! @execs.key?(appName)
        warn("Received event '#{eventName}' for unknown command '#{appName}' "+
             "with the message '#{message}'")
        return
      end
      block = @execs[appName]
      if (block != nil)
        block.call(self, op, eventName, message)
      end
      return
    end
    TraceState.nodeOnAppEvent(self, eventName, appName, op, message)
  end

  #
  # Return 'true' if all the applications on this Node are 'ready', 
  # i.e. they are all installed and ready to run
  #
  # [Return] true/false
  #
  def ready?
    if !app.nil?
      app.each { |a|
        if !a.isReady
          return false
        end
      }
    end
    return true
  end

  #
  # Add a name alias to this Resource, 
  # i.e. add this node to an additional group of resources
  #
  # - group = name of the group to add this resource to
  #
  def addGroupName(group) 
    group = group.to_s
    if (group[0] == ?/)
      group = group[1..-1]
    end
    debug("Added to group '#{group}'")
    @groups[group] = false 
    TraceState.nodeAddGroup(self, group)
    # Send an ALIAS command to this resource
    send(ECCommunicator.instance.create_message(:cmdtype => :ALIAS,
                                                :target => @nodeID,
                                                :name => group))
    # Now listen for messages on that new ALIAS address
    addr = ECCommunicator.instance.make_address(:name => group) 
    ECCommunicator.instance.listen(addr)
  end

  #
  # Set the value of the resource at a given path
  #
  # - path = the resource's path
  # - value = the value to set the resource to
  #
  def configure(path, value, status = "unknown")
    debug("Configure path '#{path}' with value '#{value}' "+
          "- status: '#{status}'")
    TraceState.nodeConfigure(self, path, value, status)
    
    #NOTE:
    # Due to GEC9 deadline this CONFIGURE is implemented here for now
    # However, this all 'configure' implementation will need to be
    # redesign to take into account the new resource handling scheme
    # which we will introduce for OMF 5.4
    if (path[0] == 'exp') && (path[1] == 'configure')
      @index = value
      desiredImage = @image.nil? ? "*" : @image
      # Send an CONFIGURE command to this resource
      # First listen for messages on that new resource address
      addr = ECCommunicator.instance.make_address(:name => @nodeID) 
      ECCommunicator.instance.listen(addr)
      # Now, Directly use the Communicator send method as this message needs to
      # be sent even if the resource is not in the "UP" state
      cmd = ECCommunicator.instance.create_message(:cmdtype => :CONFIGURE,
                                                  :path => path.join('/'),
                                                  :expID => status,
                                                  :image => desiredImage,
                                                  :target => @nodeID,
                                                  :index => @index)
      addr.expID = nil # Same address as the resource but with no expID set
      ECCommunicator.instance.listen(addr)
      ECCommunicator.instance.send_message(addr, cmd)
    end
  end

  #
  # Set the name of the image, which will be reported by this Node at check-in 
  # time.
  #
  # - imageName = name of the image to report
  #
  def image= (imageName)
    @image = imageName
    TraceState.nodeImage(self, imageName)
  end

  #
  # Save the image currently stored on the node using
  # the saveimage service
  #
  # If no image name is given, a name is formed
  # using the pattern "node-#{x}:#{y}-#{ts}.ndz",
  # where 'x' and 'y' are the node's coordinate and
  # 'ts' is a time stamp of the form 'YYYY-MM-DD-hh:mm:ss'.
  #
  # imgName = Name of file which will contain the saved image
  # imgHost = Name or IP address of host which will contain the saved image
  # disk = Disk containing the image to save (e.g. '/dev/sda')
  #
  def saveImage(imgName = nil,
                domain = OConfig.domain)
    
    begin
      disk = OMF::Services.inventory.getDefaultDisk(@nodeID, OConfig.domain).elements[1].text
    rescue
      raise "Could not retrieve default disk of node #{@nodeID} from inventory"
    end
    if imgName == nil
      ts = DateTime.now.strftime("%F-%T")
      #imgName = "node-#{x}:#{y}-#{ts}.ndz"
      imgName = ENV['USER']+"-node-#{@nodeID}-#{ts}.ndz".split(':').join('-')
    end
    
    url = "#{OConfig[:ec_config][:saveimage][:url]}/getAddress?"+
          "domain=#{domain}&img=#{imgName}&user=#{ENV['USER']}"
    response = NodeHandler.service_call(url, "Can't get netcat address/port")
    imgHost, imgPort = response.body.split(':')
    
    TraceState.nodeSaveImage(self, imgName, imgPort, disk)
    info " "
    info("- Saving image of '#{disk}' on node '#{@nodeID}'")
    info("  to the file '#{imgName}' on host '#{imgHost}'")
    info " "
    # Send an ALIAS command to this resource
    send(ECCommunicator.instance.create_message(:cmdtype => :SAVE_IMAGE,
                                                :target => @nodeID,
                                                :address => imgHost,
                                                :port => imgPort,
                                                :disk => disk))
  end

  def method_missing(method, *args)
    @propPath << "#{method.to_s}."
    if (type, id, prop = @propPath.to_s.split(".")).length >= 3
      m = match("#{type}/#{id}/#{prop}/@value")
      m.each do |e|
         @propPath = ""
         return e.to_s
      end
    end
    return self
  end

  def get_IP_address(interface)
     m = match("net/#{interface}/ip/@value")
     m.each do |e|
       return e.to_s
     end
  end

  def get_MAC_address(interface)
     m = match("net/#{interface}/mac/@value")
     m.each do |e|
       return e.to_s
     end
  end

  #
  # Send a message to the physical experiment Node, requesting the 
  # configuration of a link according to a set of parameters
  #
  # - parameters = a Hash with the configuration parameters of the link to set
  #
  # NOTE: when Node's and NodeSet's deferred queues will be moved to the
  # communicator, there will be no more need to go through this Node object
  # to send this message
  #
  def set_link(parameters = nil)
    return if !parameters
    message = ECCommunicator.instance.create_message(:cmdtype => :SET_LINK,
                                                     :target => @nodeID) 
    parameters.each { |k,v| message[k] = v }
    send(message)
  end

  #
  # Inform the node that somebody (most likely NodeSet) has issued
  # a request to load an image onto this node's disk.
  #
  # - image = Name of image in repository
  # - opts = Operational parameters used to issue command
  #
  def loadImage(image, opts) 
    TraceState.nodeLoadImage(self, image, opts)
  end

  #
  # Power this Node on
  #
  def powerOn()
    # Check that EC is NOT in 'Slave Mode' 
    # - If so call CMC to switch node(s) ON
    CMC.nodeOn(@nodeID) if !NodeHandler.SLAVE
    @poweredAt = Time.now
    #if !@isUp
    if @nodeStatus != STATUS_UP
      setStatus(STATUS_POWERED_ON) 
    end
  end

  #
  # Power this Node OFF
  # By default the node is being powered off softly (asked nicely to 
  # powerdown), but setting 'hard' to true the node is being powered 
  # off immediately. Use the hard power down with caution.
  #
  # - hard = optional, default false
  #
  def powerOff(hard = false)
    # Check that EC is NOT in 'Slave Mode' 
    # - If so call CMC to switch node(s) OFF
    if !NodeHandler.SLAVE
      if hard
        CMC.nodeOffHard(@nodeID)
      else
        CMC.nodeOffSoft(@nodeID)
      end
    end
    @poweredAt = -1
    setStatus(STATUS_POWERED_OFF)
  end

  # 
  # Send a 'SET_DISCONNECTION' message to the RC of this resource
  # nodes/resources involved in this experiment.
  # This message provides the RC with all the information it needs to 
  # runs this experiment in disconnected mode.
  #
  def set_disconnection
    begin
      expFile = NodeHandler.EXP_FILE
      exp = File.new(expFile).read
    rescue Exception => ex
      raise "Cannot set disconnection mode on resource '#{@nodeID}', "+
            "error when opening the original experiment file '#{expFile}' "+
            "(error: '#{ex}')"
    end
    addr = ECCommunicator.instance.make_address(:name => @nodeID) 
    cmd = ECCommunicator.instance.create_message(:cmdtype => :SET_DISCONNECTION,
                       :target => @nodeID,
                       :omlURL => OConfig[:ec_config][:omluri],
                       :exp => exp)
    ECCommunicator.instance.send_message(addr, cmd)
  end

  #
  # Reset this Node
  #
  # If we are already in RESET state, and the last reset was less than 
  # REBOOT_TIME ago, that means that the actual node is more likely still 
  # rebooting, thus do nothing here. Once that node will be done rebooting, 
  # either we will get in UP state or we will come back here and do a real 
  # reset this time. This avoids us to send many resets 
  #
  def reset()
    if (@nodeStatus == STATUS_RESET) && 
       ((Time.now.tv_sec - @poweredAt.tv_sec) < REBOOT_TIME)
      return
    else
      changed
      notify_observers(self, :before_resetting_node)
      setStatus(STATUS_RESET)
      debug("Resetting node")
      CMC::nodeReset(@nodeID)
      @checkedInAt = -1
      @poweredAt = Time.now
      changed
      notify_observers(self, :after_resetting_node)
    end
  end

  # 
  # Report a RESET event that happened on the NA for this Node
  #
  def reportAgentReset()
    #if @isUp
    if @nodeStatus == STATUS_UP
      warn "agent reset itself"
      setStatus(STATUS_AGENT_RESET)
      #@isUp = false
      #setStatus(STATUS_RESET)
      @checkedInAt = -1
      #@checkedInAtEl.attributes['ts'] = '-1'
      changed
      notify_observers(self, :agent_reset)
    end
  end

  #
  # This Node just checked in. Check if the image is correct and
  # then inform all observers of the joyous event.
  #
  # - initialName = Initial name of node
  # - agentVersion = Version of node agent
  # - image = Name of image installed on node
  #
  def checkIn(initialName, agentVersion, image)
    info("Checked in as #{initialName} booting off #{image}")
    if (@image != nil && image != @image)
      warn("Expected image '", @image, "', but node reported '", image, "'.")
      changed
      notify_observers(self, :node_wrong_image)
      reset()
      return
    end
    setStatus(STATUS_CHECKED_IN)
  end

  #
  # Set a property on this Node, which can be retrieved later
  #
  # - name = Name of property
  # - value = Value of property
  #
  def setProperty(name, value)
    if (@properties[name] == value)
      return
    end

    #if (!@properties.key?(name))
    # @propertyEls[name] = @propertiesEl.add_element(name)
    #end
    @properties[name] = value
    TraceState.nodeProperty(self, name, value)
    #el = @propertyEls[name]
    #el.text = value
    #el.add_element('history', {'ts' => NodeHandler.getTS()}).text = value
  end
  #
  # Short cut for 'setProperty'.
  #
  def []= (name, value)
    setProperty(name, value)
  end

  #
  # Return the value of a property on the node
  #
  # - name = Name of property
  #
  # [Return] Value of property
  #
  def getProperty(name)
    @properties[name]
  end
  #
  # Short cut for 'getProperty'.
  #
  def [] (name)
    getProperty(name)
  end

  # 
  # Process a received ENROLLED message from this Node
  #
  # - groupArray = an Array with the names of all the groups within the 
  #              original YOAURE/ALIAS message with which this NA has enrolled
  #
  # NOTE: For GEC9, we leave that as is, however, this should be merged into the 
  # processing of a configure when we will introduce the new resource handling 
  # scheme in OMF 5.4
  def enrolled(cmdObj)
    # First, If this is the first ENROLLED that we received, set the state to UP
    # and perform the associated tasks
    if @nodeStatus != STATUS_UP
      #@isUp = true
      setStatus(STATUS_UP)
      @checkedInAt = Time.now
      debug "Node #{self} is Up and Enrolled"
      send_deferred
      changed
      notify_observers(self, :node_is_up)
    end
    
    # Now, if this ENROLL specifies a list of group this NA has enrolled to
    # then process them
    if cmdObj.name != nil
      cmdObj.name.split(' ').each { |group|
        if @groups.has_key?("#{group}")
          if !@groups[group] 
            @groups[group] = true
            debug "Node #{self} is Enrolled in group '#{group}'"
            changed
            notify_observers(self, :node_is_up)
          end
        end
      }
    end

    # Finally, check if this node is enrolled in all its group
    # If so, then set it as enrolled for the _ALLGROUPS_ group too!
    allEnrolled = true
    @groups.each { |k,v|
      if (k != "_ALLGROUPS_") && (v == false) then allEnrolled = false; end
    }
    if allEnrolled
      @groups["_ALLGROUPS_"] = true
      debug "Node #{self} is Enrolled in ALL its groups"
      changed
      notify_observers(self, :node_is_up)
    end
  end
  
  #
  # When a node is being removed from all topologies, the Topology
  # class calls this method to notify it. The removed node propagates
  # this notification to the ECCommunicator.instance.instance and also to the 
  # NodeSets which it belongs to.
  #
  def notifyRemoved()
    ECCommunicator.instance.send_reset(@nodeID)
    setStatus(STATUS_DOWN)
    changed
    notify_observers(self, :node_is_removed)
  end

  #
  # Return the result of an XPath match with this Node's root element at
  # its seed.
  #
  # - xpathExpr = XPath to match
  #
  def match(xpathExpr)
    el = TraceState.getNodeState(self)
    m = REXML::XPath.match(el, xpathExpr)
    return m
  end

  #
  # Return a String with this Node's ID
  #
  # [Return] a String with this Node's ID
  #
  def to_s()
    return "#{@nodeID}"
  end

  private

  #
  # Create a new Node object
  #
  def initialize(name)
    @nodeID = name
    super("node::#{@nodeID}")
    @index = nil
    @propPath = ""
    @groups = Hash.new  # name of nodeSet groups this node belongs to
    @groups["_ALLGROUPS_"] = false
    #@apps = Hash.new
    #@isUp = false
    @nodeStatus = STATUS_DOWN
    #@senderSeq = 0
    @execs = Hash.new
    @deferred = []

    @@nodes[name] = self
    @image = nil
    @poweredAt = -1
    @checkedInAt = -1

    @properties = Hash.new
    TraceState.nodeAdd(self, @nodeID)
    debug "Created node '#{name}'"
     
    # This flag is 'false' when this node is in a temporary disconnected (from 
    # the Contorl Network) state, and is 'true' when this node reconnects to 
    # the Control Network
    @reconnected = false
  end

  #
  # Set the status of this Node
  #
  # - status = new status for this Node
  #
  def setStatus(status)
    @nodeStatus = status
    TraceState.nodeStatus(self, status)
  end

  #
  # Send a command to this Node
  #
  # - command = Command to send
  # - args = Array of parameters for this command
  #
  def send(cmdObj)
    if @nodeStatus == STATUS_UP
      cmdObj.target = @nodeID
      addr = ECCommunicator.instance.make_address(:name => @nodeID)
      ECCommunicator.instance.send_message(addr, cmdObj)
    else
      debug "Deferred message: '#{cmdObj.to_s}'"
      @deferred << cmdObj
    end
  end

  #
  # Send all deferred messages if there are any and if all the nodes are up
  # 
  def send_deferred()
    #if (@deferred.size > 0 && @isUp)
    if (@deferred.size > 0 && @nodeStatus == STATUS_UP)
      da = @deferred
      @deferred = []
      da.each { |cmdObj|
        debug "send_deferred '#{cmdObj.to_s}'"
        send(cmdObj)
      }
    end
  end

end
