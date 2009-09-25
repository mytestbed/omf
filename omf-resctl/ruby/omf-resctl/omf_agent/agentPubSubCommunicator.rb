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
# = agentPubsubCommunicator.rb
#
# == Description
#
# This file implements a Publish/Subscribe Communicator for the Node Agent.
# This PubSub communicator is based on XMPP. 
# This current implementation uses the library XMPP4R.
#
# NOTE: Extensive modification by TR from the original code from Javid
# TODO: Remove or Comment debug messages marked as 'TDEBUG'
#
require "omf-common/omfPubSubService"
require 'omf-common/lineSerializer'

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Node Agent (NA) aka Resource Controller will use this Communicator to 
# send/receive messages to/from the Node Handler (NH) aka Experiment Controller
# This Communicator is based on the Singleton design pattern.
#
class AgentPubSubCommunicator < MObject

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
  def AgentPubSubCommunicator.instantiated?
    return @@instantiated
  end   
      
  #
  # Create a new Communicator 
  #
  def initialize ()
    @@myName = nil
    @@service = nil
    @@IPaddr = nil
    @@systemNode = nil
    @@expID = nil
    @@sessionID = nil
    @@pubsubNodePrefix = nil
    @@instantiated = true
    @queue = Queue.new
    Thread.new {
      while event = @queue.pop
        execute_command(event)
      end
    }
    start(NodeAgent.instance.config('comm')['xmpp_server'])
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
  #
  def start(jid_suffix)
    
    debug "Connecting to PubSub Server: '#{jid_suffix}'"
    # Set some internal attributes...
    @@IPaddr = getControlAddr()
    
    # Create a Service Helper to interact with the PubSub Server
    begin
      @@service = OmfPubSubService.new(@@IPaddr, "123", jid_suffix)
      # Start our Event Callback, which will process Events from
      # the nodes we will subscribe to
      @@service.add_event_callback { |event|
        @queue << event
      }
    rescue Exception => ex
      error "Failed to create ServiceHelper for PubSub Server '#{jid_suffix}' - Error: '#{ex}'"
    end
    
    # keep the connection to the PubSub server alive by sending a ping every hour
    # otherwise clients will be listed as "offline" in Openfire after a timeout
    Thread.new do
      while true do
        sleep 3600
        debug("Sending a ping to the XMPP server (keepalive)")
        @@service.ping        
      end
    end
    
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
  
    # If we already know our IP Address, no need to proceed
    if @@IPaddr != nil
      return @@IPaddr
    end

    # If we are on a Linux Box, we parse the output of 'ifconfig' 
    if AgentPubSubCommunicator.isPlatformLinux?
      interface = NodeAgent.instance.config('comm')['local_if']
      lines = IO.popen("ifconfig #{interface} | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'", "r").readlines
      if (lines.length > 0)
          @@IPaddr = lines[0].chomp
      end
    else
    # not implemented for other OS
      @@IPaddr = "0.0.0.0"
    end

    # Couldnt get the Mac Address, terminate this NA
    if (@@IPaddr.nil?)
      error "Cannot determine IP address of the Control Interface"
      exit
    end
    
    # All good
    debug("Local control IP address: #{@@IPaddr}")
    # quick hack for testing
    # return "10.0.0.5"
    return @@IPaddr
  end
  
  alias localAddr getControlAddr

  #
  # Reset this Communicator
  #
  def reset
    # Leave all Pubsub nodes that we might have joined previously 
    @@service.leave_all_pubsub_nodes
    # Re-subscribe to the System Pubsub node for this node
    sysNode = "/#{DOMAIN}/#{SYSTEM}/#{@@IPaddr}"
    while (!@@service.join_pubsub_node(sysNode))
       debug "Resetting - System node '#{sysNode}' does not exist (yet) on the PubSub server - retrying in 10s"
       sleep 10
       start(NodeAgent.instance.config('comm')['xmpp_server'])
    end
  end
  
  #
  # Unsubscribe from all nodes
  # Delete the PubSub user
  # Disconnect from the PubSub server
  # This will be called when the node shuts down
  #
  def quit
    @@service.quit
  end
  
  #
  # Send a message to the NH
  #
  # -  msgArray = the array of text to send
  #
  def send(*msgArray)
    send!(0, *msgArray)
  end

  #
  # Send a heartbeat back to the NH
  #
  def sendHeartbeat()
    send!(0, :HB, -1, -1, -1, -1)
  end

  #
  # This method is just here for backward compatibility with the original TCP Server 
  # communicator.Previously (TCP Server Comm), each message had a sequence number, 
  # and the comms had to ignore duplicate messages already received. Using a PubSub 
  # communication scheme, this is no longer required. However, since we don't want 
  # to modify the NA's code yet (will do in the future!), we need this here to keep 
  # it happy.
  #
  def ignoreUpTo(number)
    # do nothing...
  end

      
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
      error "Session and Exp IDs are NIL"
      # TODO: Shall we return some error message back to the controller?
      raise "ERROR - Session and Exp IDs are NIL"
      return 
    end
    # Now subscribe to all the groups (i.e. the PubSub nodes)  
    groups.each { |group|
      fullNodeName = "#{@@pubsubNodePrefix}/#{group.to_s}"
      if @@service.join_pubsub_node(fullNodeName)
        debug "Subscribed to PubSub node: '#{fullNodeName}'"
      else
        debug "Failed to subscribe to PubSub node: '#{fullNodeName}'"
      end
    }
  end
      
  #
  # Send a message to the NH
  #
  # - seqNo = sequence number of the message to send
  # - msgArray = the array of text to send
  #
  def send!(seqNo, *msgArray)
    # Build Message  
    message = "#{@@myName} 0 #{LineSerializer.to_s(msgArray)}"
    item = Jabber::PubSub::Item.new
    msg = Jabber::Message.new(nil, message)
    item.add(msg)

    # Send it
    dst = "#{@@pubsubNodePrefix}/#{@@myName}"
    debug("Send to '#{dst}' - msg: '#{message}'")
    begin
      @@service.publish_to_node("#{dst}", item)        
    rescue Exception => ex
      error "Failed sending to '#{dst} - msg: '#{message}' - error: '#{ex}'"
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
      incomingPubSubNode =  event.first_element("items").attributes['node']

      # TODO: this is the initial support for XML messages between EC and RC
      # Currently this is only used for EXECUTE, due to the need of XML support to pass 
      # the OML configuration from the EC to the RC. In the future, all comms should use XML
      # and this should be cleaner.
      if message == nil
        xmlMessage = event.first_element("items").first_element("item").first_element("message").first_element("body").first_element("EXECUTE")
        NodeAgent.instance.execCommand2(xmlMessage)
        return
      end
    rescue Exception => ex
      return
    end
        
    # Parse the Message to extract the Command
    # (when parsing, keep the full message to send it up to NA later)
    argArray = message.split(' ')
    if (argArray.length < 1)
      error "Message too short! '#{message}'"
      return
    end
    cmd = argArray[0].upcase
        
    # First Check if we sent that message ourselves, if so do nothing
    if (@@myName != nil) && (cmd == @@myName.upcase) 
        return
    end

    # Then - We check if this Command should trigger any specific task within this Communicator
    debug "Received on '#{incomingPubSubNode}' - msg: '#{message}'"
    begin
      case cmd
      when "EXEC"
      when "KILL"
      when "STDIN"
      when "EXIT"
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
      when "LIST"
      when "SET_MACTABLE"
      when "NOOP"
        return
      when "JOIN"
        join_groups(argArray[1, (argArray.length-1)])
      when "ALIAS"
        join_groups(argArray[1, (argArray.length-1)])
      when "YOUARE"
        # YOUARE format (see AgentCommands): YOUARE <sessionID> <expID> <desiredImage> <name> <aliases>
        # <sessionID> Session ID
        # <expID> Experiment ID
        # <desiredImage> the name of the image that this node should have
        # <name> becomes the Agent Name for this Session/Experiment.
        # <aliases> optional aliases for this NA
        if (argArray.length < 5)
         error "YOUARE message too short: '#{message}'"
         return
        end
        # Store the Session and Experiment IDs given by the NH's communicator
        @@sessionID = argArray[1]
        @@expID = argArray[2]
        debug "Processing YOUARE - SessionID: '#{@@sessionID}' - ExpID: '#{@@expID}'"
        # Join the global PubSub nodes for this session / experiment
        n = "/#{DOMAIN}/#{SESSION}/#{@@sessionID}/#{@@expID}"
        m = "/#{DOMAIN}/#{SESSION}/#{@@sessionID}"
        if (!@@service.join_pubsub_node(n) || !@@service.join_pubsub_node(m)) then
          error "YOUARE message node does not exist: '#{n}'"
          error "Possibly received an old YOUARE message from a previous experiment - discarding"
          return
        end
        # Store this node ID and full PubSub path for this session / experiment
        @@pubsubNodePrefix = "/#{DOMAIN}/#{SESSION}/#{@@sessionID}/#{@@expID}"        
        @@myName = argArray[4]
        list = Array.[](argArray[4])
        # Check if the desired image is installed on that node, 
	# if yes or if a desired image is not required, then continue
	# if not, then ignore this YOUARE
	desiredImage = argArray[3]
	if (desiredImage != NodeAgent.instance.imageName() && desiredImage != '*')
          debug "Processing YOUARE - Requested Image: '#{desiredImage}' - Current Image: '#{NodeAgent.instance.imageName()}'"
	  send("WRONG_IMAGE", NodeAgent.instance.imageName())
	  return
	end
        # If there are some optional aliases, add them to the list of groups to join
        if (argArray.length > 1)
          argArray[4,(argArray.length-1)].each { |name|
            list.push(name)
          }
        end
        join_groups(list)
      # ELSE CASE -  We don't know this command, log that and discard it.
      else
        debug "Unsupported command: '#{cmd}' - not passing it to NA" 
        return
      end # END CASE
    rescue Exception => ex
      error "Failed to process message: '#{message}' - Error: '#{ex}'"
      return
    end
    
    # Finally - We can pass the full message up to the NodeAgent
    NodeAgent.instance.execCommand(argArray)
  end

end #class
