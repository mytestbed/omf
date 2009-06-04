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
    # TODO: fetch the pubsub hostname via inventory
    # fetch the interface from config file
    start("10.0.0.200")
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
    
    info "TDEBUG - START PUBSUB - #{jid_suffix}"
    # Set some internal attributes...
    @@IPaddr = getControlAddr()
    
    # Create a Service Helper to interact with the PubSub Server
    begin
      @@service = OmfPubSubService.new(@@IPaddr, "123", jid_suffix)
      # Start our Event Callback, which will process Events from
      # the nodes we will subscribe to
      #debug "TDEBUG - start 1"
      @@service.add_event_callback { |event|
        #debug "TDEBUG - New Event - '#{event}'" 
        execute_command(event)
        #debug "TDEBUG - Finished Processing Event" 
      }         
    rescue Exception => ex
      error "ERROR - start - Creating ServiceHelper - PubSubServer: '#{jid_suffix}' - Error: '#{ex}'"
    end

    #debug "TDEBUG - start 2"
    debug "Connected to PubSub Server: '#{jid_suffix}'"
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
    # return "10.0.1.1"
    return @@IPaddr
  end
  
  alias localAddr getControlAddr

  #
  # Reset this Communicator
  #
  def reset
    debug "TDEBUG - reset - 1"
    # Leave all Pubsub nodes that we might have joined previously 
    #@@service.leave_all_pubsub_nodes_except("/#{DOMAIN}/#{SYSTEM}")
    @@service.leave_all_pubsub_nodes
    
    sysNode = "/#{DOMAIN}/#{SYSTEM}/#{@@IPaddr}"
    
    while (!@@service.node_exist?(sysNode))
      debug "CDEBUG - Node #{sysNode} does not exist (yet) on the PubSub server - retrying in 10s"
      sleep 10
      start("10.0.0.200")
    end
    
    # Subscribe to the default 'system' pubsub node
    @@service.join_pubsub_node(sysNode)
    #debug "TDEBUG - reset - Joined PubSub node '#{@@sysNode}'" 
    debug "TDEBUG - reset - 2"
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
  def send!(seqNo, *msgArray)
    # Build Message  
    message = "#{@@myName} 0 #{LineSerializer.to_s(msgArray)}"
    item = Jabber::PubSub::Item.new
    msg = Jabber::Message.new(nil, message)
    item.add(msg)

    # Send it
    dst = "#{@@pubsubNodePrefix}/#{@@myName}"
    debug("Send to: #{dst} - message: '#{message}'")
    begin
      debug "send! - A"
      @@service.publish_to_node("#{dst}", item)        
      debug "send! - B"
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
    #debug "TDEBUG - execute_command - A"
    begin
      message = event.first_element("items").first_element("item").first_element("message").first_element("body").text
    rescue Exception => ex
      debug "CDEBUG - execute_command() - Not a message event, ignoring: '#{event}'"
      return
    end
    #debug "TDEBUG - execute_command - B - message: '#{message}'"
        
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
      when "NOOP"
        return
      when "JOIN"
        join_groups(argArray[1, (argArray.length-1)])
        
      when "ALIAS"
        join_groups(argArray[1, (argArray.length-1)])
    
      when "YOUARE"
        # YOUARE format (see AgentCommands): YOUARE <sessionID> <expID> <name> <aliases>
        # <sessionID> Session ID
        # <expID> Experiment ID
        # <name> becomes the Agent Name for this Session/Experiment.
        # <aliases> optional aliases for this NA
        
        if (argArray.length < 4)
          error "ERROR - execute_command() - YOUARE - message too short: '#{message}'"
          return
        end
        
        # Store the Session and Experiment IDs given by the NH's communicator
        @@sessionID = argArray[1]
        @@expID = argArray[2]
        debug "TDEBUG - execute_command() - Set SessionID / ExpID: '#{@@sessionID}' / '#{@@expID}'"
        # Join the global PubSub nodes for this session / experiment
        n = "/#{DOMAIN}/#{SESSION}/#{@@sessionID}/#{@@expID}"
        if (!@@service.node_exist?(n)) then
          error "ERROR - execute_command() - YOUARE - node does not exist: '#{n}'"
          error "ERROR - possibly received a lingering YOUARE message from a previous experiment - discarding"
          return
        end
        @@service.join_pubsub_node(n)
        n = "/#{DOMAIN}/#{SESSION}/#{@@sessionID}"
        @@service.join_pubsub_node(n)
        # Store the full PubSub path for this session / experiment
        @@pubsubNodePrefix = "/#{DOMAIN}/#{SESSION}/#{@@sessionID}/#{@@expID}"        
        
        @@myName = argArray[3]
        list = Array.[](argArray[3])
        # If there are some optional aliases, add them to the list of groups to join
        if (argArray.length > 1)
          argArray[3,(argArray.length-1)].each { |name|
            list.push(name)
          }
        end
        join_groups(list)    
          
      else
        # if we sent this message to the NH ourselves, do nothing  
        if (@@myName!=nil) then
          if (cmd==@@myName.upcase) then 
            return
          end
        end
        # When nothing else matches - We don't know this command, log that and discard it.        
        NodeAgent.debug "execute_command() - Unsupported command: '#{cmd}' - not passing it to NA" 
        return
      end
    rescue Exception => ex
      error "ERROR - execute_command() - Bad message: '#{message}' - Error: '#{ex}' - still passing it to NA"
    end
    
    # Second - Now that we can pass the full message up to the NodeAgent
    debug "execute_command - PASSING CMD to NA - 1"
    NodeAgent.instance.execCommand(argArray)
    debug "execute_command - PASSING CMD to NA - 2"
  end

end #class
