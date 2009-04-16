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
require "util/omfPubSubService"
require 'util/lineSerializer'

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
    @@macID = nil
    @@controlIF = nil
    @@systemNode = nil
    @@expID = nil
    @@sessionID = nil
    @@pubsubNodePrefix = nil
    @@instantiated = true
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
  def start(jid_suffix, password, control_interface)
    
    info "TDEBUG - START PUBSUB - #{jid_suffix} - #{password} - #{control_interface}"
    # Set some internal attributes...
    @@controlIF = control_interface
    @@macID = getControlAddr()
    userjid = "#{@@macID}@#{jid_suffix}"
    pubsubjid = "pubsub.#{jid_suffix}"
    
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
      error "ERROR - start - EXITING..."
      exit
    end

    #debug "TDEBUG - start 2"
    debug "Connected to PubSub Server: '#{pubsubjid}'"
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
    if @@macID != nil
      return @@macID
    end
  
    # If we are on a Linux Box, we parse the output of 'ifconfig' 
    if NodeAgentPubSubCommunicator.isPlatformLinux?
      # Regexp filter to catch the MAC address from 'ifconfig'
      match = /[.0-9a-fA-F]+\:[.0-9a-fA-F]+\:[.0-9a-fA-F]+\:[.0-9a-fA-F]+\:[.0-9a-fA-F]+\:[.0-9a-fA-F]+/
      lines = IO.popen("/sbin/ifconfig #{@@controlIF}", "r").readlines
      if (lines.length >= 2)
        mac = lines[0][match]
        # Replace ':' with '-' to please PubSub Server
        @@macID = mac.gsub(/[\:]/, '-') 
      end
    else
    # WINDOWS HACK
      @@macID = "11-00-00-00-00-11"
    end

    # Couldnt get the Mac Address, terminate this NA
    if (@@macID.nil?)
      error "Cannot determine MAC of Control Interface"
      exit
    end
    
    # All good
    debug("Local control MAC ID: #{@@macID}")
    return @@macID
  end

  alias localAddr getControlAddr

  #
  # Reset this Communicator
  #
  def reset
    debug "TDEBUG - reset - 1"
    # Leave all Pubsub nodes that we might have joined previously 
    @@service.leave_all_pubsub_node()
    # Subscribe to the default 'system' pubsub node
    @@systemNode = "/#{DOMAIN}/#{SYSTEM}/#{@@macID}"
    begin
      @@service.join_pubsub_node(@@systemNode)
    rescue Exception => ex
      error "ERROR - reset - Joining PubSub node '#{@@systemNode}' - Error: '#{ex}'"
      error "ERROR - reset - EXITING..."
      exit
    end
    #debug "TDEBUG - reset - Joined PubSub node '#{@@systemNode}'" 
    debug "TDEBUG - reset - 2"
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
    debug "TDEBUG - execute_command - A"
    begin
      message = event.first_element("items").first_element("item").first_element("message").first_element("body").text
    rescue Exception => ex
      error "ERROR - execute_command() - Cannot parse Event '#{event}'"
      return
    end
    debug "TDEBUG - execute_command - B - message: '#{message}'"
        
    # Parse the Message to extract the Command
    # (when parsing, keep the full message to send it up to NA later)
    argArray = message.split(' ')
    if (argArray.length < 2)
      error "ERROR - execute_command() - Message too short! '#{message}'"
      return
    end
    cmd = argArray[1].upcase # ignore <target> field
        
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
        join_groups(argArray[2, (argArray.length-1)])
        
      when "ALIAS"
        join_groups(argArray[2, (argArray.length-1)])
    
      when "YOUARE"
        # YOUARE format (see AgentCommands): <target> YOUARE <name> <seqnumber> <aliases>
        # <name> becomes the Agent Name for this Session/Experiment.
        # <seqnumber> an Integer, this is only kept here for backward compatibility with TCPServer 
	#             communicator so we dont have to modify the NA code. 
	#             TODO: phase this out!
        # <aliases> optional aliases for this NA
        @@myName = argArray[2]
	list = Array.[](argArray[2])
	# If there are some optional aliases, add them to the list of groups to join
	if (argArray.length > 4)
	  argArray[4,(argArray.length-1)].each { |name|
	    list.push(name)
	  }
	end
        join_groups(list)
    
      when "IDS"
        # Store the Session and Experiment IDs given by the NH's communicator
        @@sessionID = argArray[2]
        @@expID = argArray[3]
        debug "TDEBUG - execute_command() - Set SessionID / ExpID: '#{@@sessionID}' / '#{@@expID}'"
        # Join the global PubSub nodes for this session / experiment
        n = "/#{DOMAIN}/#{SESSION}/#{@@sessionID}"
        @@service.join_pubsub_node(n)
        n = "/#{DOMAIN}/#{SESSION}/#{@@sessionID}/#{@@expID}"
        @@service.join_pubsub_node(n)
        # Store the full PubSub path for this session / experiment
        @@pubsubNodePrefix = "/#{DOMAIN}/#{SESSION}/#{@@sessionID}/#{@@expID}"
        # Return Now, this cmd is only used between NH and NA communicators
        return
    
      # When nothing else match - We don't know this command, log that and discard it.
      else
        NodeAgent.debug "execute_command() - Unsupported command: '#{cmd}'" 
        return
      end
    rescue Exception => ex
      error "ERROR - execute_command() - Bad message: '#{message}' - Error: '#{ex}'"
      error "ERROR - execute_command() - EXITING..."
      exit
    end
    
    # Second - Now that we can pass the full message up to the NodeAgent
    debug "execute_command - PASSING CMD to NA - 1"
    NodeAgent.instance.execCommand(argArray)
    debug "execute_command - PASSING CMD to NA - 2"
  end

end #class
