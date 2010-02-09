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
  # Return the node at location 'x'@'y'. If no node exists, create a new one.
  # - x = x coordinate of the node to return
  # - y = y coordinate of the node to return
  #
  # [Return] an existing or a new Node object 
  #
  def Node.at! (name)
    n = @@nodes[name]
    if !n.kind_of?(Node)
      if CMC::nodeActive?(name)
        n = Node.new(name)
      else
        raise ResourceException.new("Node #{name} is NOT active")
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
  def Node.allReconnected?
    @@nodes.each { |n|
      if !n.isReconnected?
        return false
      end
    }
    return true
  end

  attr_reader :nodeId, :MAC

  # True if node is up, false otherwise
  #attr_reader :isUp

  # A set listing all the group memberships for this node
  attr_reader :groupMembership

  # ID of shadow xml node
  attr_reader :nodeId
  
  # IP of interface for experiment
  attr_writer :ipExp

  # Number of rules for TC
  attr_writer :rulesNb

  #list of rules applied on this node
  attr_writer :rulesList

  # Name of image to expect on node
  attr_reader :image

  # Time the node was powered up
  attr_reader :poweredAt

  # Time the node checked in
  attr_reader :checkedInAt

  public :to_s

  #
  # Return true is this node is in the UP state
  #
  # [Return] true/false
  #
  def isUp()
    return (@nodeStatus == STATUS_UP)
  end

  def isEnrolled(group)
    if @groups.has_key?(group)
      return @groups[group]
    else
      error "Node '#{@nodeId}' does not belong to group '#{group}'"
      return false
    end
  end

  #
  # Return the IP address of the node's control interface (this method queries the Inventory DB for this IP)
  #
  # [Return] a String holding the IP address
  #
  def getControlIP()
    
    # Check if EC is running in 'Slave Mode'
    if NodeHandler.SLAVE_MODE()
      # Yes - Then there can only be 1 NA to talk to, it's the 'Slave' NA on localhost
      return "127.0.0.1"
    end

    # Query the Inventory GridService for the Control IP address of this node
    url = "#{OConfig[:ec_config][:inventory][:url]}/getControlIP?name=#{@nodeId}&domain=#{OConfig.domain}"
    response = NodeHandler.service_call(url, "Can't get Control IP for '#{@nodeId}' on domain '#{OConfig.domain}' from INVENTORY")
    doc = REXML::Document.new(response.body)
    # Parse the Reply to retrieve the control IP address
    doc.root.elements.each("ERROR") { |e|
      error "OConfig - No Control IP found for '#{@nodeId}' - val: #{e.get_text.value}"
      raise "OConfig - #{e.get_text.value}"
    }
    doc.root.elements.each("/CONTROL_IP") { |v|
       return v.get_text.value
    }
  end

  #
  # Return the name of this Node object. The current convention is Name(X,Y)="nodeX-Y". However, we will mode to a flat numbering soon...
  # 
  # [Return] a String holding the Node's name
  #
  #def getNodeName()
  #  return "node"+x.to_s+"-"+y.to_s
  #end
  #
  # Same as getNodeName
  #
  #def name()
  #  return "node"+x.to_s+"-"+y.to_s
  #end

  #
  # Set a MAC address attribute for this node
  #
  # - mac = mac address to set
  #
  def setMAC(mac)
    @MAC = mac
  end

  #
  # Set the list of MAC address that this Node object should ignore (MAC filtering)
  #
  # - macList =  list of the MAC addresses to ignore/blacklist
  #
  def setBlockedMACList(macList)
    macList.each { |m|
      @blockedMACList.add(m)
    }
  end

 #
 # Remove a given MAC address from the blacklist of this Node
 #
 # - macAddr = the MAC address to remove
 #
  def removeBlockedMAC(macAddr)
    @blockedMACList.delete(macAddr)
  end

 #
 # Print a list of the MAC addresses that are blacklisted by this Node
 #
 # - macAddr = the MAC address to remove
 #
  def printBlockedMACList()
    info "Node '#{@nodeId}' - Blocked MAC(s):"
    @blockedMACList.each { |mac|
      info " - #{mac}"
    }
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
    #debug("Message for app '#{appId}' - '#{message}'")
    appName, op = appId.split('/')
    if (eventName.upcase == "STDOUT") && NodeHandler.SHOW_APP_OUTPUT()
       # When requested by user, print SDOUT events on our own standard-out
       info("From app '#{appId}' - '#{message}'")
    end
    if (appName =~ /^exec:/)
      if ! @execs.key?(appName)
        warn("Received '#{eventName}' for unknown command '#{appName}' - '#{message}'")
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
  # Return 'true' if all the applications on this Node are 'ready', i.e. they are all installed and ready to run
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
  # Add a name alias to this Node, i.e. add this node to an additional group of nodes
  #
  # - group = name of the group to add this Node to
  #
  def addGroupName(group) #, individual = nodeId)
    group = group.to_s
    if (group[0] == ?/)
      group = group[1..-1]
    end
    debug("Added to group '#{group}'")
    @groups[group] = false 
    TraceState.nodeAddGroup(self, group)

    alias_cmd = Communicator.instance.getCmdObject(:ALIAS)
    alias_cmd.target = @nodeId
    alias_cmd.name = group
    send(alias_cmd)
  end

  #
  # Set the value of the resource at a given path
  #
  # - path = the resource's path
  # - value = the value to set the resource to
  #
  def configure(path, value, status = "unknown")
    if (value.kind_of?(String) && value[0] == '%'[0])
      # if value starts with "%" perform certain substitutions
      value = value[1..-1]  # strip off leading '%'
      value.sub!(/%x/, @x.to_s)
      value.sub!(/%y/, @y.to_s)
    end
    ipExp(value)
    ipexp = ipExp?()
    TraceState.nodeConfigure(self, path, value, status)
  end

    #
    # Set the IP of the interface used for experiment.
    #   
    #   - ipExp = @ip of the interface
    #        
  def ipExp(ip)
    @ipExp = ip
  end

  #
  #  Return the Ip of the interface used for experiment
  #    
  #  [Return] @Ip
  #

  def ipExp?()
        return @ipExp
  end


  #
  # Set the name of the image, which will be reported by this Node at check-in time.
  #
  # - imageName = name of the image to report
  #
  def image= (imageName)
    #@apps['builtin:save_image'] = NodeBuiltin.new('save_image', params, self, procEl, 'ISSUED')
    @image = imageName
    TraceState.nodeImage(self, imageName)
  end

  #
  # Save the image currently stored on the node's disk to
  # 'nsfDir', a NSF mountable directory and name the
  # image 'imgName'.
  #
  # If no image name is given, a name is formed
  # using the pattern "node-#{x}:#{y}-#{ts}.ndz",
  # where 'x' and 'y' are the node's coordinate and
  # 'ts' is a time stamp of the form 'YYYY-MM-DD-hh:mm:ss'.
  #
  # imgName = Name of file which will contain the saved image
  # imgHost = Name or IP address of host which will contain the saved image
  # disk = Disk containing the image to save (e.g. '/dev/hda')
  #
  def saveImage(imgName = nil,
                domain = OConfig.domain,
                disk = OConfig[:tb_config][:default][:frisbee_default_disk])

    if imgName == nil
      ts = DateTime.now.strftime("%F-%T")
      #imgName = "node-#{x}:#{y}-#{ts}.ndz"
      imgName = ENV['USER']+"-node-#{@nodeId}-#{ts}.ndz".split(':').join('-')
    end
        
    url = "#{OConfig[:tb_config][:default][:saveimage_url]}/getAddress?domain=#{domain}&img=#{imgName}&user=#{ENV['USER']}"
    response = NodeHandler.service_call(url, "Can't get netcat address/port")
    imgHost, imgPort = response.body.split(':')
    
    TraceState.nodeSaveImage(self, imgName, imgPort, disk)
    info " "
    info("- Saving image of '#{disk}' on node '#{@nodeId}'")
    info("  to the file '#{imgName}' on host '#{imgHost}'")
    info " "
    save_cmd = Communicator.instance.getCmdObject(:SAVE_IMAGE)
    save_cmd.target = @nodeId
    save_cmd.address = imgHost
    save_cmd.port = imgPort
    save_cmd.disk = disk
    send(save_cmd)
  end

  #
  # Send a message to the physical experiment Node, requesting the activation of the MAC blacklist
  #
  # - toolToUse = the software tool to use to enforce the blacklist (iptable, ebtable, or mackill)
  #
  def setMACTable(toolToUse)
    @blockedMACList.each{ |mac|
      mac_cmd = Communicator.instance.getCmdObject(:SET_MACTABLE)
      mac_cmd.target = @nodeId
      mac_cmd.cmd = toolToUse
      mac_cmd.address = mac
      send(mac_cmd)
    }
  end

  #
  #  Send message with rule parameters to enable traffic shaping
  #  
  #  - values = values of parameters for the action : values = [ipDst,delay,delayvar,delayCor,loss,lossCor,bw,bwBuffer,bwLimit,corrupt,duplic,portDst,portRange, portProtocol].  Value -1 = not set, except for portRange, 0
  #  - ipDst = ip of the destination host
  # 

  def setTrafficRules(values)
    nbRules = @rulesId
    values = values + [@rulesId]
    ipDst = values[0].to_s
    if (@rulesList.size > 0)
      i=0
      while (i<@rulesList.size)
        puts @rulesList[i][0].to_s+"rulesList"
        #
        #    UPDATE OF A RULE WHILE EXPERIMENT IS RUNNING
        #     
        #     if (@rulesList[i][0] == ipDst)
        #     send('SET_REMOVERULES',rulesList[i][0],rulesList[i][11],rulesList[i][12],rulesList[i][13])
        #     j=1
        #     while (j!=13)
        #       if (@rulesList[i][j] != values[j] and values[j] != -1)
        #         @rulesList[i][j] = values[j]
        #     end
        #     j = j+1   
        #   end
        #   values = @rulesList[i]      
        # end
        
        i = i+1
      end
    end
    send('SET_TRAFFICRULES',values[0],values[1],values[2],values[3],values[4],values[5],values[6],values[7], values[8], values[9], values[10], values[11], values[12], values[13], values[14],values[15])
    @rulesList = @rulesList + [values]
    @rulesId = @rulesId + 1
    puts " -- "
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
    # Check that EC is NOT in 'Slave Mode' - If so call CMC to switch node(s) ON
    if !NodeHandler.SLAVE_MODE()
      CMC.nodeOn(@nodeId)
    end
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
    # Check that EC is NOT in 'Slave Mode' - If so call CMC to switch node(s) OFF
    if !NodeHandler.SLAVE_MODE()
      if hard
        CMC.nodeOffHard(@nodeId)
      else
        CMC.nodeOffSoft(@nodeId)
      end
    end
    @poweredAt = -1
    setStatus(STATUS_POWERED_OFF)
  end

  #
  # Enrol this Node into the experiment
  #
  def enroll()
    desiredImage = @image.nil? ? "*" : @image
    enroll_cmd = Communicator.instance.getCmdObject(:ENROLL)
    enroll_cmd.expID = Experiment.ID
    enroll_cmd.image = desiredImage
    enroll_cmd.target = @nodeId
    Communicator.instance.sendCmdObject(enroll_cmd)
  end

  #
  # Reset this Node
  #
  # If we are already in RESET state, and the last reset was less than REBOOT_TIME ago,
  # That means that the actual node is more likely still rebooting, thus do nothing here
  # Once that node will be done rebooting, either we will get in UP state or we will
  # come back here and do a real reset this time. This avoids us to send many resets 
  #
  def reset()
    if (@nodeStatus == STATUS_RESET) && ((Time.now.tv_sec - @poweredAt.tv_sec) < REBOOT_TIME)
      return
    else
      changed
      notify_observers(self, :before_resetting_node)
      setStatus(STATUS_RESET)
      debug("Resetting node")
      CMC::nodeReset(@nodeId)
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
  # Process a received a timestamp/heartbeat from this Node
  #
  # - sendSeqNo = sender sequence number
  # - recvSeqNo = receiver sequence number
  # - timestamp = timestamp value for this heartbeat
  #
  def heartbeat(sendSeqNo, recvSeqNo, timestamp)
    TraceState.nodeHeartbeat(self, sendSeqNo, recvSeqNo, timestamp)
  end

  # 
  # Process a received ENROLLED message from this Node
  #
  # - groupArray = an Array with the names of all the groups within the 
  #              original YOAURE/ALIAS message with which this NA has enrolled
  #
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
      # when we receive the first ENROLL, send a NOOP message to the NA. This is necessary
      # since if NA is reset or restarted, it would re-subscribe to its system PubSub node and
      # would receive the last command sent via this node (which is YOUARE if we don't send NOOP)
      # from the PubSub server (at least openfire works this way). It would then potentially
      # try to subscribe to nodes from a past experiment.
      #Communicator.instance.sendNoop(@nodeId)
    end
    
    # Now, if this ENROLL specifies a list of group this NA has enrolled to
    # then process them
    if cmdObj.alias != nil
      cmdObj.alias.split(' ').each { |group|
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
    # If so, then set it as enrolled for the _ALL_ group too!
    allEnrolled = true
    @groups.each { |k,v|
      if (k != "_ALL_") && (v == false) then allEnrolled = false; end
    }
    if allEnrolled
      @groups["_ALL_"] = true
      debug "Node #{self} is Enrolled in ALL the groups"
      changed
      notify_observers(self, :node_is_up)
    end
    #TraceState.nodeHeartbeat(self, sendSeqNo, recvSeqNo, timestamp)
  end
  
  #
  # When a node is being removed from all topologies, the Topology
  # class calls this method to notify it. The removed node propagates
  # this notification to the Communicator.instance.instance and also to the NodeSets which
  # it belongs to.
  #
  def notifyRemoved()
    Communicator.instance.removeNode(@nodeId)
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
  # Set the 'Reconnected' flag for this node. This flag is 'false' when this
  # node is in a temporary disconnected (from the Contorl Network) state, and
  # is 'true' when this node reconnects to the Control Network
  #
  def setReconnected
    @reconnected = true
  end

  #
  # Return the value of the 'Reconnected' flag for this node. 
  # This flag is 'false' when this node is in a temporary disconnected (from 
  # the Contorl Network) state, and is 'true' when this node reconnects to 
  # the Control Network
  #
  def isReconnected?
    return @reconnected
  end

  #
  # Return a String with this Node's ID
  #
  # [Return] a String with this Node's ID
  #
  def to_s()
    #return "#{@nodeId}(#{@aliases.to_a.join(', ')})"
    return "#{@nodeId}"
  end

  private

  #
  # Create a new Node object
  #
  def initialize(name)
    @nodeId = name
    super("node::#{@nodeId}")
    @rulesId = 1
    @rulesList = []
    @groups = Hash.new  # name of nodeSet groups this node belongs to
    @groups["_ALL_"] = false
    #@apps = Hash.new
    #@isUp = false
    @nodeStatus = STATUS_DOWN
    #@senderSeq = 0
    @execs = Hash.new
    @blockedMACList = Set.new
    @MAC = nil
    @deferred = []

    @@nodes[name] = self
    @image = nil
    @poweredAt = -1
    @checkedInAt = -1

    @properties = Hash.new
    TraceState.nodeAdd(self, @nodeId)
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
    #@statusEl.text = status
    #@statusEl.add_element('history', {'ts' => NodeHandler.getTS()}).text = status
  end

  #
  # Send a command to this Node
  #
  # - command = Command to send
  # - args = Array of parameters for this command
  #
  def send(cmdObj)
    if @nodeStatus == STATUS_UP
      cmdObj.target = @nodeId
      Communicator.instance.sendCmdObject(cmdObj)
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
