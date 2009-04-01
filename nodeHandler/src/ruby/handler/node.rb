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
# = node.rb
#
# == Description
#
# This file defines the 'Node' class
#
#
require 'util/mobject'
require 'handler/prototype'
require 'rexml/document'
require 'rexml/element'
require 'rexml/xpath'
require 'util/arrayMD'
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

  @@nodes = ArrayMD.new

  #
  # Return the node at location 'x'@'y'. If no node exists, return nil.
  # - x = x coordinate of the node to return
  # - y = y coordinate of the node to return
  #
  # [Return] a Node object or 'nil' if no node exits at that location
  #
  def Node.[] (x, y)
    n = @@nodes[x][y]
    # take care of ArrayMD elements
    return n.kind_of?(Node) ? n : nil
  end

  #
  # Return the node at location 'x'@'y'. If no node exists, create a new one.
  # - x = x coordinate of the node to return
  # - y = y coordinate of the node to return
  #
  # [Return] an existing or a new Node object 
  #
  def Node.at! (x, y)
    n = @@nodes[x][y]
    if !n.kind_of?(Node)
      if CMC::nodeActive?(x, y)
        n = Node.new(x, y)
      else
        raise ResourceException.new("Node #{x}@#{y} is NOT active")
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
    @@nodes.each(&block)
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

  attr_reader :x, :y, :MAC

  # True if node is up, false otherwise
  attr_reader :isUp

  # A set listing all the group memberships for this node
  attr_reader :groupMembership

  # ID of shadow xml node
  attr_reader :nodeId

  # Name of image to expect on node
  attr_writer :image

  # Time the node was powered up
  attr_reader :poweredAt

  # Time the node checked in
  attr_reader :checkedInAt

  public :to_s

  #
  # Return the IP address of the node's control interface (this method queries the Inventory DB for this IP)
  #
  # [Return] a String holding the IP address
  #
  def getControlIP()
    
    # Check if NH is running in 'Slave Mode'
    if NodeHandler.SLAVE_MODE()
      # Yes - Then there can only be 1 NA to talk to, it's the 'Slave' NA on localhost
      return "127.0.0.1"
    end

    # Query the Inventory GridService for the Control IP address of this node
    url = "#{OConfig.INVENTORY_SERVICE}/getControlIP?x=#{x}&y=#{y}&domain=#{OConfig.GRID_NAME}"
    response = NodeHandler.service_call(url, "Can't get Control IP for x: #{x} y: #{y} on '#{OConfig.GRID_NAME}' from INVENTORY")
    doc = REXML::Document.new(response.body)
    # Parse the Reply to retrieve the control IP address
    ip = nil
    doc.root.elements.each("/CONTROL_IP") { |v|
      ip = v.get_text.value
    }
    # If no IP found in the reply... raise an error
    if (ip == nil)
      doc.root.elements.each('/ERROR') { |e|
        error "OConfig - No Control IP found for x: #{x} y: #{y} - val: #{e.get_text.value}"
        raise "OConfig - #{e.get_text.value}"
      }
    else
      return ip
    end
  end

  #
  # Return the name of this Node object. The current convention is Name(X,Y)="nodeX-Y". However, we will mode to a flat numbering soon...
  # 
  # [Return] a String holding the Node's name
  #
  def getNodeName()
    return "node"+x.to_s+"-"+y.to_s
  end
  #
  # Same as getNodeName
  #
  def name()
    return "node"+x.to_s+"-"+y.to_s
  end

  #
  # Set a MAC address attribut for this node
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
    info "Node [#{@x},#{@y}] - Blocked MAC(s):"
    @blockedMACList.each { |mac|
      info " - #{mac}"
    }
  end

  #
  # Add an application to this Node
  #
  # - app = Application definition
  # - vName = Virtual name given to this app
  # - paramBindings = Parameter bindings for this application
  # - env = Envioronment to set before starting application
  #
  def addApplication(app, vName, paramBindings, env)
    #procEl = getConfigNode(['apps'])
    #@apps["app:#{vName.to_s}"] = NodeApp.new(app, vName, paramBindings, env, self, procEl)
    debug("Add application #{vName}:#{app} to #{self}")
    TraceState.nodeAddApplication(self, app, vName, paramBindings, env)
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
    debug("Message for app '#{appId}' - '#{message}'")
    appName, op = appId.split('/')
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
    #name = "/#{group}/#{individual}"
    debug("Added to group '#{group}'")
    @groups.add(group)
    #@@nodeAliases[name] = self

    TraceState.nodeAddGroup(self, group)
    Communicator.instance.addToGroup(@nodeId, group)
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
    TraceState.nodeConfigure(self, path, value, status)
    #el = getConfigNode(path)
    #el.text = value
    #el.add_attribute('status', status)
  end

  #
  # Set the name of the image, which will be reported by this Node at check-in time.
  #
  # - imageName = name of the image to report
  #
  def image= (imageName)
    @image = imageName
    TraceState.nodeImage(self, imageName)
    #@imageEl.text = imageName
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
                imgHost = OConfig.IMG_HOST,
                disk = OConfig.DEFAULT_DISK)

    if imgName == nil
      ts = DateTime.now.strftime("%F-%T")
      #imgName = "node-#{x}:#{y}-#{ts}.ndz"
      imgName = ENV['USER']+"-node-#{x}-#{y}-#{ts}.ndz".split(':').join('-')
    end
    TraceState.nodeSaveImage(self, imgName, imgHost, disk)
    #procEl = getConfigNode(['apps'])
    #info("Saving #{disk} from #{@nodeId} as \"tmp/#{imgName}\"")
    #params = {:imgName => imgName, :nsfDir => nsfDir, :disk => disk}
    #@apps['builtin:save_image'] = NodeBuiltin.new('save_image', params, self, procEl, 'ISSUED')
    info("- Saving disk image from node #{@nodeId} in the file '#{imgName}'")
    info("  (disk images are located at: '#{imgHost}')")
    info("  (disk '#{disk}') will be imaged")    
    send('SAVE_IMAGE', imgName, imgHost, disk)
  end

  #
  # Send a message to the physical experiment Node, requesting the activation of the MAC blacklist
  #
  # - toolToUse = the software tool to use to enforce the blacklist (iptable, ebtable, or mackill)
  #
  def setMACTable(toolToUse)
    @blockedMACList.each{ |mac|
      send('SET_MACTABLE', toolToUse, mac)
    }
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
    #TraceState.nodeLoadImage(node, image, opts)
    #procEl = getConfigNode(['apps'])
    #appEl = ImageNodeApp.new(opts, self, procEl)
    #appEl.setStatus('ISSUED')
    #@apps['builtin:load_image'] = appEl
  end

  #
  # Set the status of a configurable resource of this Node
  #
  # - path = Name of resource
  # - status = Status of resource
  # - extra = Optional hash table defining additional status attributes
  #
  def configureStatus(path, status, optional = nil)
    el = getConfigNode(path)
    el.add_attribute('status', status)
    optional.each {|k, v|
      el.add_attribute(k.to_s, v)
    } if optional != nil
  end

  #
  # Power this Node on
  #
  def powerOn()
    #CMC::nodeOn(x, y)
    @poweredAt = Time.now
    #@poweredAtEl.attributes['ts'] = NodeHandler.getTS()
    if !@isUp
      setStatus(STATUS_POWERED_ON) 
    end
  end

  #
  # Power this Node off
  #
  def powerOff()
    #CMC::nodeOffSoft(x, y)
    @poweredAt = -1
    setStatus(STATUS_POWERED_OFF)
    #@poweredAtEl.attributes['ts'] = '-1'
  end

  #
  # Reset this Node
  #
  def reset()
    changed
    notify_observers(self, :before_resetting_node)
    @isUp = false
    setStatus(STATUS_RESET)
    debug("Resetting node")
    CMC::nodeReset(x, y)
    @checkedInAt = -1
    @poweredAt = Time.now
    #@checkedInAtEl.attributes['ts'] = '-1'
    #@poweredAtEl.attributes['ts'] = NodeHandler.getTS()
    changed
    notify_observers(self, :after_resetting_node)
  end

  # 
  # Report a RESET event that happened on the NA for this Node
  #
  def reportAgentReset()
    if @isUp
      warn "agent reset itself"
      setStatus(STATUS_AGENT_RESET)
      @isUp = false
      setStatus(STATUS_RESET)
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
  # Send a command to node. This is for Experts/Debug ONLY
  # and should be used with care.
  #
  # - command = Command to send
  # - args = Array of parameters for that command
  #
  def send!(command, *args)
    send(command, *args)
  end

  #
  # Process a received a timestamp/heartbeadt from this Node
  #
  # - sendSeqNo = sender sequence number
  # - recvSeqNo = receiver sequence number
  # - timestamp = timestamp value for this heartbeat
  #
  def heartbeat(sendSeqNo, recvSeqNo, timestamp)
    # check if we received all packets
    #inSequence?(sendSeqNo)
    if (! @isUp)
      # first heartbeat, looks like node is up and ready
      @isUp = true
      setStatus(STATUS_UP)
      @checkedInAt = Time.now
      #@checkedInAtEl.attributes['ts'] = NodeHandler.getTS()
      changed
      notify_observers(self, :node_is_up)
      send_deferred
    end
    TraceState.nodeHeartbeat(self, sendSeqNo, recvSeqNo, timestamp)
    #@heartbeat.add_attribute('ts', timestamp)
    #@heartbeat.add_attribute('sentPackets', sendSeqNo)
    #@heartbeat.add_attribute('receivedPackets', recvSeqNo)
  end
  
  #
  # When a node is being removed from all topologies, the Topology
  # class calls this method to notify it. The removed node propagates
  # this notification to the Communicator and also to the NodeSets which
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

  private

  #
  # Create a new Node object
  #
  def initialize(x, y)
    @nodeId = "n_#{x}_#{y}"
    super("node::#{@nodeId}")

    @x = x
    @y = y
    @groups = Set.new  # name of nodeSet groups this node belongs to
    #@apps = Hash.new
    @isUp = false
    #@senderSeq = 0
    @execs = Hash.new
    @blockedMACList = Set.new
    @MAC = nil
    @deferred = []

    @@nodes[x][y] = self
    @image = nil
    @poweredAt = -1
    @checkedInAt = -1

    @properties = Hash.new
    ipAddress = getControlIP()
    Communicator.instance.enrollNode(self, @nodeId, ipAddress)
    TraceState.nodeAdd(self, @nodeId, x, y)
    debug "Created node #{x}@#{y}"
     
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
  def send(command, *args)
    #debug("node#send: args(#{args.length})'#{args.join('#')}")
    if (@isUp)
      Communicator.instance.send(nodeId, command, args)
    else
      #raise "Node not up. Embed command in 'onNodeUp' block"
      debug "Deferred message: #{command} #{@nodeId} #{args.join(' ')}"
      @deferred << [command, args]
    end
  end

  #
  # Send all deferred messages if there are any and if all the nodes are up
  # 
  def send_deferred()
    if (@deferred.size > 0 && @isUp)
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
  # Return an XML element whose path is relative
  # to this Node's root element (@el)
  #
  # - path = an Array holding the path to the requested element
  #
  # [Return] an XML element
  #
  def getConfigNode(path)
    parent = @el
    el = nil
    path.each {|name|
      if (el = parent.elements[name]) == nil
        el = parent.add_element(name)
      end
      parent = el
    }
    return el
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

end
