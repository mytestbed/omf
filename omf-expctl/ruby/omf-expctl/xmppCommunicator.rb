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
require 'omf-expctl/agentCommands'

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
    @handlerCommands = Hash.new
    @@myName = nil
    @@service = nil
    @@IPaddr = nil
    @@controlIF = nil
    @@systemNode = nil
    @@expID = nil
    @@expNode = nil
    @@sessionID = nil
    @@pubsubNodePrefix = nil
    @@instantiated = true
    @queue = Queue.new
    Thread.new {
      while event = @queue.pop
        execute_command(event)
      end
    }
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
  def start(jid_suffix, sessionID, expID)
    
    getControlAddr()
    info "TDEBUG - START PUBSUB - #{jid_suffix}"
    # Set some internal attributes...
    @@sessionID = sessionID
    @@expID = expID
    
    # Create a Service Helper to interact with the PubSub Server
    begin
      @@service = OmfPubSubService.new(expID, "123", jid_suffix)
      # Start our Event Callback, which will process Events from
      # the nodes we will subscribe to
      @@service.add_event_callback { |event|
        #debug "TDEBUG - New Event - '#{event}'" 
        @queue << event
        #debug "TDEBUG - Finished Processing Event" 
      }         
    rescue Exception => ex
      error "ERROR - start - Creating ServiceHelper - PubSubServer: '#{jid_suffix}' - Error: '#{ex}'"
    end

    begin
      @@service.remove_all_pubsub_nodes
    rescue Exception => ex
      error "ERROR - Removing old PubSub nodes - Error: '#{ex}'"
      error "ERROR - Most likely reason: Cannot connect to PubSubServer: '#{jid_suffix}'"
      error "ERROR - bailing out."
      exit!
    end

    #debug "TDEBUG - start 2"
    debug "Connected to PubSub Server: '#{jid_suffix}'"
        
    # let the gridservice do this:
    #@@service.create_pubsub_node("/#{DOMAIN}")
    #@@service.create_pubsub_node("/#{DOMAIN}/#{SYSTEM}")
        
    @@service.create_pubsub_node("/#{DOMAIN}/#{SESSION}")
    @@service.create_pubsub_node("/#{DOMAIN}/#{SESSION}/#{sessionID}")    
    @@expNode = "/#{DOMAIN}/#{SESSION}/#{sessionID}/#{expID}"
    @@service.create_pubsub_node("#{@@expNode}")
    
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
  
  #############################################################################################################  
  #############################################################################################################  
  #############################################################################################################
  #
  # This method sends a message to one or multiple nodes
  # Format: <command arg1 arg2 ...>
  #
  # - target =  a String with the name of the group of node(s) that should process this message
  # - command = the NodeAgent command that should be executed
  # - msgArray = an Array with the arguments for this NodeAgent command
  #
  def send(target, command, msgArray = [])
    msg = "#{command} #{LineSerializer.to_s(msgArray)}"
    if (target == "*")
      send!(msg, "#{@@expNode}")
    else
      target.gsub!(/^"(.*?)"$/,'\1')
      targets = target.split(' ')
      targets.each {|tgt|
        send!(msg, "#{@@expNode}/#{tgt}")
      }
    end
   end

  #
  # This method sends a reset message to all connected nodes
  #
  def sendReset()
    send!("RESET", "#{@@expNode}")
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
    # create the experiment pubsub node so the node can subscribe to it
    # after receiving the YOUARE message
    psNode = "#{@@expNode}/#{name}"
    @@service.create_pubsub_node(psNode)
    # send the YOUARE to the system pubsub node
    psNode = "/#{DOMAIN}/#{SYSTEM}/#{ipAddress}"
    send!("YOUARE #{@@sessionID} #{@@expID} #{name}",psNode)
  end

  #
  # This sends a NOOP to the /Domain/System/IPaddress
  # node to overwrite the last buffered YOUARE
  #
  # - name = name of the node to receive the NOOP
  #
  def sendNoop(name)
    node = @name2node[name]
    ipAddress = node.getControlIP()
    psNode = "/#{DOMAIN}/#{SYSTEM}/#{ipAddress}"
    send!("NOOP", psNode)
  end

  #
  # This method is called when a node is removed from
  # an experiment. First, it resets the node to
  # unsubscribe it from the experiment-related
  # PubSub nodes, and then removes its PubSub node.
  #
  # - name = name of the node to remove
  #
  def removeNode(name)
    @name2node[name] = nil
    send!("RESET", "#{@@expNode}/#{name}")
    @@service.remove_pubsub_node("#{@@expNode}/#{name}")
  end

  #
  # This method adds a node to an existing/new group
  # (a node can belong to multiple groups)
  #
  # - nodeName = name of the node 
  # - groupName =  name of the group to add the node to
  #
  def addToGroup(nodeName, groupName)
    @@service.create_pubsub_node("#{@@expNode}/#{groupName}")
    send!("ALIAS #{groupName}", "#{@@expNode}/#{nodeName}")
  end

  #
  # This method is called when the experiment is finished or cancelled
  #
  def quit()
    @@service.remove_all_pubsub_nodes
    @@service.quit
  end
  
  #
  # Process an Event coming from an application running on 
  # one of the nodes.
  #
  # - eventName = name of the received Event
  # - appId = Id of the monitored application 
  # - msg = Optional message
  #
  def onAppEvent(eventName, appId, msg = nil)
    eventName = eventName.to_s.upcase
    if (msg != nil && eventName == "STDOUT" && msg[0] == ?#)
      ma = msg.slice(1..-1).strip.split
      cmd = ma.shift
      msg = ma.join(' ')
      if cmd == 'WARN'
        MObject.warn('xmppCommunicator', msg)
      elsif cmd == 'ERROR'
        MObject.error('xmppCommunicator', msg)
      else
        MObject.debug('xmppCommunicator', msg)
      end
      return
    end

    debug("xmppCommunicator(#{eventName}): '#{msg}'")
    if (eventName == "STDOUT")
      a = LineSerializer.to_a(msg)
      processCommand(a)
    elsif (eventName == "DONE.ERROR")
      error("xmppCommunicator failed: ", msg)
      @server = nil
    end
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
        
  def send!(message, dst)
    if (message.length == 0) then
      error "send! - detected attempt to send an empty message"
      return
    end
    if (dst.length == 0 ) then
      error "send! - empty destination"
      return
    end
    item = Jabber::PubSub::Item.new
    msg = Jabber::Message.new(nil, message)
    item.add(msg)
  
    # Send it
    #debug("*** Sending '#{message}' to '#{dst}' ***")
    @@service.publish_to_node("#{dst}", item)        
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
      # received a XMPP fragment that is not a text message, such as an (un)subscribe notification
      # we're ignoring those
      # error "ERROR - execute_command() - Cannot parse Event '#{event}'"
      return
    end
    #debug "message received: '#{message}'"
        
    # Parse the Message to extract the Command
    # (when parsing, keep the full message to send it up to NA later)
    argArray = message.split(' ')
    if (argArray.length < 1)
      error "ERROR - execute_command() - Message too short, ignoring: '#{message}'"
      return
    end
    cmd = argArray[0].upcase
        
    # First - Here we check if this Command should trigger any specific task within this Communicator
    case cmd
    when "EXEC"
    when "HB"
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
    when "DOMAIN"
    # we've sent this command ourselves, so we can safely ignore it
    else
      begin
      cmd = argArray[2].upcase
      case cmd
      when "HB"
        # we do not send the NOOP here, we do that only for the first HB in node.rb:heartbeat()
      when "APP_EVENT"
      when "DEV_EVENT"
      when "ERROR"                

        # When nothing else matches - We don't know this command, log that and discard it.
      else
        NodeHandler.debug "execute_command() - Unsupported command: '#{cmd}' - not passing it to NH" 
        return
      end
      rescue Exception => ex
        error "ERROR - execute_command() - Bad message: '#{message}' - Error: '#{ex}' - still passing it to NH"
      end
      processCommand(argArray)
    end
  end

   #
   # This method processes the command comming from an agent
   #
   #  - argArray = command line parsed into an array
   #
   def processCommand(argArray)
     #debug "Process message '#{argArray.join(' ')}'"
     if argArray.size < 2
       raise "Command is too short '#{argArray.join(' ')}'"
     end
     senderId = argArray.delete_at(0)
     sender = @name2node[senderId]
     
     if (sender == nil)
       debug "Received message from unknown sender '#{senderId}': '#{argArray.join(' ')}'"
       return
     end
     # get rid of the sequence number
     argArray.delete_at(0)
     command = argArray.delete_at(0)
     # First lookup this comand within the list of handler's Commands
     method = @handlerCommands[command]
     # Then, if it's not a handler's command, lookup it up in the list of agent's commands
     if (method == nil)
       begin
         method = @handlerCommands[command] = AgentCommands.method(command)
       rescue Exception
         warn "Unknown command '#{command}' received from '#{senderId}'"
         return
       end
     end
     begin
       # Execute the command
       reply = method.call(self, sender, senderId, argArray)
     rescue Exception => ex
       #error("Error ('#{ex}') - While processing agent command '#{argArray.join(' ')}'")
       debug("Error ('#{ex.backtrace.join("\n")}') - While processing agent command '#{argArray.join(' ')}'")
     end
   end
    
end #class
