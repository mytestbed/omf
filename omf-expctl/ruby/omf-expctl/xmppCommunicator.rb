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
# = xmppCommunicator.rb
#
# == Description
#
# This file implements a Publish/Subscribe Communicator for the Node Handler.
# This PubSub communicator is based on XMPP. 
# This current implementation uses the library XMPP4R.
#

require "omf-common/omfPubSubService"
require 'omf-common/lineSerializer'
require 'omf-common/mobject'

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Node Agent (NA) aka Resource Controller will use this Communicator to 
# send/receive messages to/from the Node Handler (NH) aka Experiment Controller
# This Communicator is based on the Singleton design pattern.
#
class XmppCommunicator < MObject

  DOMAIN = "Domain"
  SYSTEM = "System"
  SESSION = "Session"

  include Singleton
  @@instantiated = false
    
  #
  # Return the Instantiation state for this Singleton
  #
  # [Return] true/false
  #
  def XmppCommunicator.instantiated?
    return @@instantiated
  end   
      
  #
  # Create a new Communicator 
  #
  def initialize ()
    @name2node = Hash.new
    @@myName = nil
    @@service = nil
    @@IPaddr = nil
    @@controlIF = nil
    @@systemNode = nil
    @@domain = nil
    @@expID = nil
    @@sessionID = nil
    @@pubsubNodePrefix = nil
    @@instantiated = true
  end

  # 
  # Return the x coordinate for this NA 
  # Raises an error message if the coordinate is not set/available
  #
  # [Return] x coordinate
  #
  def x
    if (@@x.nil?)
      raise "Cannot determine X coordinate"
    end
    return @@x
  end

  # 
  # Set the x coordinate for this NA 
  #
  # - x = value for the X coordinate
  #
  def setX(x)
    @@x = x
  end
  # 
  # Return the y coordinate for this NA 
  # Raises an error message if the coordinate is not set/available
  #
  # [Return] y coordinate
  #
  def y
    if (@@y.nil?)
      raise "Cannot determine X coordinate"
    end
    return @@y
  end

  # 
  # Set the y coordinate for this NA 
  #
  # - y = value for the Y coordinate
  #
  def setY(y)
    @@y = y
  end      
      
  #
  # Configure and start the Communicator.
  # This method instantiates a PubSub Service Helper, which will connect to the
  # PubSub server, and handle all the communication from/towards this server.
  # This method also sets the callback method, which will be called upon incoming
  # messages. 
  #
  # - jid_suffix = [String], JabberID suffix, this is the full host/domain name of 
  #                the PubSub server, e.g. 'norbit.npc.nicta.com.au'. 
  # - password = [String], password to use for this PubSud client
  # - control_interface = [String], the interface connected to Control Network
  #
  def start(jid_suffix, password, domain, sessionID, expID)
    
    info "TDEBUG - START PUBSUB - #{jid_suffix} - #{password}"
    # Set some internal attributes...
    userjid = "expctl@#{jid_suffix}"
    pubsubjid = "pubsub.#{jid_suffix}"
    @@domain = domain
    @@sessionID = sessionID
    @@expID = expID
    
    # Create a Service Helper to interact with the PubSub Server
    begin
      @@service = OmfPubSubService.new(userjid, password, pubsubjid)
      # Start our Event Callback, which will process Events from
      # the nodes we will subscribe to
      #debug "TDEBUG - start 1"
      @@service.add_event_callback { |event|
        debug "TDEBUG - New Event - '#{event}'" 
        execute_command(event)
        debug "TDEBUG - Finished Processing Event" 
      }         
    rescue Exception => ex
      error "ERROR - start - Creating ServiceHelper - PubSubServer: '#{pubsubjid}' - Error: '#{ex}'"
    end

    #debug "TDEBUG - start 2"
    debug "Connected to PubSub Server: '#{pubsubjid}'"

    @@service.create_pubsub_node("#{domain}")
    @@service.create_pubsub_node("#{domain}/session")
    @@service.create_pubsub_node("#{domain}/system")
    @@service.create_pubsub_node("#{domain}/session/#{sessionID}")
    @@service.create_pubsub_node("#{domain}/session/#{sessionID}/#{expID}")

  end

  #
  # Return 'true' if this Communicator is running on a linux platform
  #
  # [Return] true/false
  #
  def self.isPlatformLinux?
    return RUBY_PLATFORM.include?('linux')
  end

  #
  # Return the MAC address of the control interface
  #
  # This method assumes that the 'ifconfig' command returns something like:
  #
  # eth1      Link encap:Ethernet  HWaddr 00:0D:61:46:1E:E1
  #           inet addr:10.10.101.101  Bcast:10.10.255.255  Mask:255.255.0.0
  #           UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
  #           RX packets:118965 errors:0 dropped:0 overruns:0 frame:0
  #           TX packets:10291 errors:0 dropped:0 overruns:0 carrier:0
  #           collisions:0 txqueuelen:1000
  #           RX bytes:17394487 (16.5 MiB)  TX bytes:1073233 (1.0 MiB)
  #           Interrupt:11 Memory:eb024000-0
  #
  #  [Return] a String holding a MAC Address
  #
  def getControlAddr()
  
    # If we already know our Mac Address, no need to proceed
    if @@IPaddr != nil
      return @@IPaddr
    end
  
    # If we are on a Linux Box, we parse the output of 'ifconfig' 
    if XmppCommunicator.isPlatformLinux?
      lines = IO.popen("ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'", "r").readlines
      if (lines.length > 0)
          @@IPaddr = lines[0].chomp
      end
    else
    # not implemented for other OS
      @@IPaddr = "0.0.0.0"
    end

    # Couldnt get the Mac Address, terminate this NA
    if (@@IPaddr.nil?)
      error "Cannot determine IP address of Control Interface"
      exit
    end
    
    # All good
    debug("Local control IP address: #{@@IPaddr}")
    return @@IPaddr
  end

  alias localAddr getControlAddr
  
  #
  # Unsubscribe from all nodes
  # This will be called when the node shuts down
  #
  def unsubscribe
    @@service.leave_all_pubsub_node()
  end
  
  #############################################################################################################  
  #############################################################################################################  
  #############################################################################################################
  #
  # This method sends a message to one or multiple nodes
  # Format: <sequenceNo target command arg1 arg2 ...>
  #
  # - target =  a String with the name of the group of node(s) that should process this message
  # - command = the NodeAgent command that should be executed
  # - msgArray = an Array with the arguments for this NodeAgent command
  #
  def send(target, command, msgArray = [])
    msg = "S #{target} #{command} #{LineSerializer.to_s(msgArray)}"
    debug("Send message: ", msg)
    write(msg)
   end

  #
  # This method sends a message unreliably. 
  # This means sending a message with a sequence number of 0.
  # Format: <0 target command arg1 arg2 ...>
  #
  # - target =  a String with the name of the group of node(s) that should process this message
  # - command = the NodeAgent command that should be executed
  # - msgArray = an Array with the arguments for this NodeAgent command
  #
  def sendUnreliably(target, command, msgArray = [])
    msg = "s #{target} #{command} #{LineSerializer.to_s(msgArray)}"
    debug("Send unreliable message: ", msg)
    write(msg)
  end

  #
  # This method sends a reset message to all connected nodes
  #
  def sendReset()
    write("R")
  end

  #
  # This method enrolls 'node' with 'ipAddress' and 'name'
  # When this node checks in, it will automatically
  # get 'name' assigned.
  #
  # - node =  id of the node to enroll
  # - name = name to give to the node once enrolled
  # - ipAddress = IP address of the node to enroll 
  #
  def enrolNode(node, name, ipAddress)
    @name2node[name] = node
    write("a #{ipAddress} #{name}")
    psNode = "#{@@domain}/system/#{ipAddress}"
    @@service.create_pubsub_node(psNode)
    send!("IDS #{@@sessionID} #{@@expID}",psNode)
    send!("YOUARE #{name}",psNode)
  end

  #
  # This method removes a node from the tcpCommunicator's list of 'alive' nodes.
  # When a given 'Node' object is being removed from all the existing 
  # topologies, it calls this method to notify the tcpCommunicator, so 
  # subsequent messages received from the real physical node will be 
  # discarded by the Commnunicator in the processCommand() call.
  # Furthermore, 'X' command is sent to the commServer to remove all
  # group associated to this node at the commServer level. Finally, a
  # 'RESET' command is sent to the real node.
  #
  # - name = name of the node to remove
  #
  def removeNode(name)
    @name2node[name] = nil
    write("X #{name}")
    write("s #{name} RESET")
  end

  #
  # This method adds a node to an existing/new group
  # (a node can belong to multiple group)
  #
  # - nodeName = name of the node 
  # - groupName =  name of the group to add the node to
  #
  def addToGroup(nodeName, groupName)
    write("A #{nodeName} #{groupName}")
    psNode = "#{@@domain}/session/#{@@sessionID}/#{@@expID}/#{nodeName}"
    @@service.create_pubsub_node(psNode)
    @@service.join_pubsub_node(psNode)
    @@service.create_pubsub_node("#{@@domain}/session/#{@@sessionID}/#{@@expID}/#{groupName}")
    send!("ALIAS #{groupName}", psNode)
  end

  #
  # This methods sends a 'quit' message to all the nodes
  #
  def quit()
    begin
      write('q')
      sleep 2
    rescue
      #ignore
    end
    @@service.remove_pubsub_node("#{@@domain}/session/#{@@sessionID}")
    @@service.remove_pubsub_node("#{@@domain}/session/#{@@sessionID}/#{@@expID}")
#    @@service.leave_pubsub_node(node)
#    @@service.remove_pubsub_node("#{domain}/session/#{sessionID}/#{expID}") # remove each node TODO
  end

  #############################################################################################################  
  #############################################################################################################  
  #############################################################################################################
      
  private
     
  #
  # Subscribe to some PubSub nodes (i.e. nodes = groups = message boards)
  #
  # - groups = an Array containing the name (Strings) of the group to subscribe to
  #
  def join_groups (groups)
    
    # First check if we already have received the session and experiment IDs
    # If not something went wrong!
    if (@@pubsubNodePrefix == nil)
      debug "join_groups - ERROR - Session / Exp IDs are NIL"
      # TODO: Shall we return some error message back to the controller?
      raise "ERROR - Session / Exp IDs are NIL"
      return 
    end
	
    # Now subscribe to all the groups (i.e. the PubSub nodes)  
    #debug "TDEBUG - join_groups - Groups to join: #{groups.to_s}"
    groups.each { |group|
      fullNodeName = "#{@@pubsubNodePrefix}/#{group.to_s}"
      debug "TDEBUG - join_groups - a group: #{fullNodeName}"
      @@service.join_pubsub_node(fullNodeName)
      debug "TDEBUG - join_groups - Subcribed to PubSub node: '#{fullNodeName}'"
    }
  end
      
  #
  # Send a message to the NH
  #
  # - seqNo = sequence number of the message to send
  # - msgArray = the array of text to send
  #
  # def send!(seqNo, *msgArray)
  # 
  #   # Build Message  
  #   message = "#{@@myName} 0 #{LineSerializer.to_s(msgArray)}"
  #   item = Jabber::PubSub::Item.new
  #   msg = Jabber::Message.new(nil, message)
  #   item.add(msg)
  # 
  #   # Send it
  #   dst = "#{@@pubsubNodePrefix}/#{@@myName}"
  #   debug("Send to: #{dst} - message: '#{message}'")
  #   begin
  #     debug "send! - A"
  #     @@service.publish_to_node("#{dst}", item)        
  #     debug "send! - B"
  #   rescue Exeption => ex
  #     error "ERROR - Failed sending '#{message}' to '#{dst}' - #{ex}"
  #   end
  # end
  
  def send!(message, dst)
    item = Jabber::PubSub::Item.new
    msg = Jabber::Message.new(nil, message)
    item.add(msg)
  
    # Send it
    debug("Send to: #{dst} - message: '#{message}'")
    begin
      @@service.publish_to_node("#{dst}", item)        
    rescue Exeption => ex
      error "ERROR - Failed sending '#{message}' to '#{dst}' - #{ex}"
    end
  end
      
  #
  # Process an incoming message from the NH. This method is called by the
  # callback hook, which was set up in the 'start' method of this Communicator.
  # First, we parse the message to extract the command and its arguments.
  # Then, we check if this command should trigger some Communicator-specific actions.
  # Finally, we pass this command up to the Node Agent for further processing.
  #
  # - event:: [Jabber::PubSub::Event], and XML message send by XMPP server
  #
  # NOTE: The Payload of the received message should be of the form:
  #       <target> <command> <argument1> <argument2> etc...
  #
  #       This was the format also documented in the original TCP server communicator.
  #       However, <target> is no longer relevant in a pub/sub communication scheme.
  #       Thus, we can still currently keep this message format for backward compatibility
  #       (i.e. that way we don't modify the NA code, which can still use the old TCP server
  #       if required). Here we just ignore the <target> field. 
  #       TODO: in the future, we will phase out the <target> field.
  #
  def execute_command (event)

    # Extract the Message from the PubSub Event
    begin
      message = event.first_element("items").first_element("item").first_element("message").first_element("body").text
    rescue Exception => ex
      error "ERROR - execute_command() - Cannot parse Event '#{event}'"
      return
    end
    debug "message received: '#{message}'"
        
    # Parse the Message to extract the Command
    # (when parsing, keep the full message to send it up to NA later)
    argArray = message.split(' ')
    if (argArray.length < 1)
      error "ERROR - execute_command() - Message too short! '#{message}'"
      return
    end
    cmd = argArray[0].upcase
        
    # First - Here we check if this Command should trigger any specific task within this Communicator
    begin
      case cmd
      when "EXEC"
      when "KILL"
      when "STDIN"
      when "PM_INSTALL"
      when "APT_INSTALL"
      when "RESET"
      when "RESTART"
      when "REBOOT"
      when "MODPROBE"
      when "CONFIGURE"
      when "LOAD_IMAGE"
      when "SAVE_IMAGE"
      when "RETRY"
      when "RALLO"
      when "LIST"
      when "SET_MACTABLE"
      when "JOIN"
      when "ALIAS"
      when "YOUARE"
      when "IDS"
      when "HB"
        debug "Heartbeat received"
        return
      when "WHOAMI"
        debug "WHOAMI received"
        return
  
      # When nothing else match - We don't know this command, log that and discard it.
      else
        NodeHandler.debug "execute_command() - Unsupported command: '#{cmd}' - not passing it to NH" 
        return
      end
    rescue Exception => ex
      error "ERROR - execute_command() - Bad message: '#{message}' - Error: '#{ex}' - still passing it to NH"
    end
    
    # Second - Now that we can pass the full message up to the NodeAgent
    #debug "execute_command - PASSING CMD to NA - 1"
    #NodeHandler.instance.execCommand(argArray)
    #debug "execute_command - PASSING CMD to NA - 2"
  end
  
  #
  # This method writes a message to the commServer
  #
  # - msg =  message to write (String)
  #
  def write(msg)
    if NodeHandler.JUST_PRINT
      puts ">> MSG: #{msg}"
    else
      # just print it for now
      puts ">> MSG: #{msg}"
      
      #if @server
      #  @server.stdin(msg)
      #else
      #  error("Dropped message to node: ", msg)
      #end
    end
  end
  
end #class
