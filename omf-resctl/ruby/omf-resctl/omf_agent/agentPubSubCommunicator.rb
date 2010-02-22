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
require "omf-common/omfCommandObject"

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Node Agent (NA) aka Resource Controller will use this Communicator to 
# send/receive messages to/from the Node Handler (EC) aka Experiment Controller
# This Communicator is based on the Singleton design pattern.
#
class AgentPubSubCommunicator < MObject

  DOMAIN = "OMF"
  RESOURCE = "resources"
  PING_INTERVAL = 3600
  RETRY_INTERVAL = 10

  VALID_EC_COMMANDS = Set.new [:EXECUTE, :KILL, :STDIN, :NOOP,
                      :PM_INSTALL, :APT_INSTALL, :RPM_INSTALL, :RESET, 
                      :REBOOT, :MODPROBE, :CONFIGURE, :LOAD_IMAGE,
                      :SAVE_IMAGE, :LOAD_DATA, :SET_MACTABLE, :ALIAS,
                      :RESTART, :ENROLL, :EXIT]

  VALID_RC_COMMANDS = Set.new [:ENROLLED, :WRONG_IMAGE, :OK, :HB, :WARN, 
                      :APP_EVENT, :DEV_EVENT, :ERROR, :END_EXPERIMENT]

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
    @@myName = NodeAgent.instance.config[:agent][:name]
    @@sliceID = NodeAgent.instance.config[:agent][:slice]
    @@service = nil
    @@IPaddr = nil
    @@systemNode = nil
    @@expID = nil
    @@psGroupSlice = nil
    @@psGroupResource = nil
    @@psGroupExperiment = nil

    @@instantiated = true
    @queue = Queue.new
    Thread.new {
      while event = @queue.pop
        execute_command(event)
      end
    }
    start(NodeAgent.instance.config[:comm])
    #start(NodeAgent.instance.config[:comm][:xmpp_server])
  end
  
  #
  # Return an Object which will hold all the information required to send 
  # a command to another OMF entity.
  # This Communicator uses the OMF Command Object class.
  # 
  # The returned Command Object have at least the following public accessors:
  # - type = type of the command
  # and a variable list of other accessors, depending on the type of the command
  #
  # [Return] a Command Object holding all the information related to a given command
  #
  def getCmdObject(cmdType)
    return OmfCommandObject.new(cmdType)
  end
      
  #
  # Configure and start the Communicator.
  # This method instantiates a PubSub Service Helper, which will connect to the
  # PubSub server, and handle all the communication from/towards this server.
  # This method also sets the callback method, which will be called upon incoming
  # messages. 
  #
  # - pubsub = [Hash], a Hash with the following 3 [key, value]
  #            -- xmpp_server, JabberID suffix, this is the full host/domain name of 
  #                         the PubSub server, e.g. 'norbit.npc.nicta.com.au'. 
  #            -- xmpp_user, the username to use to connect to the server 
  #            -- xmpp_pwd, the password to use to connect to the server 
  #            IF user is not set, the RC will register a new user for itself
  #            (this will only work if the PubSub server is set to accept open registration)
  #
  #def start(jid_suffix)
  def start(pubsub)
    
    #debug "Connecting to PubSub Server: '#{jid_suffix}'"
    debug "Connecting to PubSub Server: '#{pubusub[:xmpp_server]}'"

    # Set some internal attributes...
    #@@IPaddr = getControlAddr()

    # Check if PubSub Server is reachable
    check = false
    while !check
      reply = `ping -c 1 #{pubusub[:xmpp_server]}`
      if $?.success?
        check = true
      else
        info "Could not resolve or contact: '#{pubusub[:xmpp_server]}' - Waiting #{RETRY_INTERVAL} sec before retrying..."
        sleep RETRY_INTERVAL
      end
    end

    # Create a Service Helper to interact with the PubSub Server
    begin
      if (pubusub[:xmpp_user] != nil
        debug "Using PubSub username as provided: '#{pubusub[:xmpp_user]}'"
        @@service = OmfPubSubService.new(pubusub[:xmpp_user], pubusub[:xmpp_pwd], pubusub[:xmpp_server])
      else
        debug "Using self-generated PubSub username: '#{@@sliceID}-#{@@myName}'"
        @@service = OmfPubSubService.new("#{@@sliceID}-#{@@myName}", "123", pubusub[:xmpp_server])
      end
      # Start our Event Callback, which will process Events from
      # the nodes we will subscribe to
      @@service.add_event_callback { |event|
        @queue << event
      }
    rescue Exception => ex
      error "Failed to create ServiceHelper for PubSub Server '#{pubusub[:xmpp_server]}' - Error: '#{ex}'"
      exit # No need to cleanUp, as this RC has not done anything yet...
    end
    
    # keep the connection to the PubSub server alive by sending a ping every hour
    # otherwise clients will be listed as "offline" in Openfire after a timeout
    Thread.new do
      while true do
        sleep PING_INTERVAL
        debug("Sending a ping to the XMPP server (keepalive)")
        @@service.ping        
      end
    end
    
    # Set useful PubSub Node Prefixes
    @@psGroupSlice = "/#{DOMAIN}/#{@@sliceID}" # ...created upon slice instantiation
    @@psGroupResource = "#{@@psGroupSlice}/#{RESOURCE}" # ...created upon slice instantiation
  end

  #
  # Return 'true' if this Communicator is running on a linux platform
  #
  # [Return] true/false
  #
  def self.isPlatformLinux?
    return RUBY_PLATFORM.include?('linux')
  end
  def self.isPlatformArmLinux?
    return RUBY_PLATFORM.include?('arm-linux')
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

    foundIP = false
    while !foundIP
      # If we are on a Linux Box, we parse the output of 'ifconfig' 
      if AgentPubSubCommunicator.isPlatformLinux?
        interface = NodeAgent.instance.config[:comm][:control_if]
        if AgentPubSubCommunicator.isPlatformArmLinux?
          ## arm-linux is assumed to be android platform
          lines = IO.popen("/sbin/ifconfig #{interface}", "r").readlines
          iplines = "#{lines}"
          ip_index = iplines.index('ip') + 3
          mask_index = iplines.index('mask')
          ip_length = mask_index -1 -ip_index
          @@IPaddr = iplines.slice(ip_index,ip_length)
          foundIP = true
        else
          lines = IO.popen("/sbin/ifconfig | grep -A1 #{interface} | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'", "r").readlines
          if (lines.length > 0)
            @@IPaddr = lines[0].chomp
            foundIP = true
  	  end
        end
      else
      # not implemented for other OS
        error "Cannot determine IP address of the Control Interface For this Platform"
        @@IPaddr = "0.0.0.0"
        error "Using fake IP: #{@@IPaddr}"
        foundIP = true
      end

      # Couldnt get the Mac Address, retry...
      if (@@IPaddr.nil?)
        error "Cannot determine IP address of the Control Interface ('#{interface}')"
        error "Waiting #{RETRY_INTERVAL} sec, and retrying..."
        sleep RETRY_INTERVAL
      end
    end

    # All good
    debug("Local control IP address: #{@@IPaddr}")
    return @@IPaddr
  end
  
  alias localAddr getControlAddr

  #
  # Reset this Communicator
  #
  def reset
    # Leave all Pubsub nodes that we might have joined previously 
    @@service.leave_all_pubsub_nodes
    # Re-subscribe to the 'Slice/Resource' Pubsub group for this node
    group = "#{@@psGroupResource}/#{@@myName}"
    while (!@@service.join_pubsub_node(group))
       debug "PubSub group '#{group}' does not exist on the server - retrying in #{RETRY_INTERVAL} sec"
       sleep RETRY_INTERVAL
    end
    debug "Joined PubSub group: '#{group}'"
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
  # Send a message to the EC
  #
  # -  msgArray = the array of text to send
  #
  def send(*msgArray)
    send!(0, *msgArray)
  end

  #
  # Send a heartbeat back to the EC
  #
  def sendHeartbeat()
    send!(0, :HB, -1, -1, -1, -1)
  end

  #
  # This method sends a command to one or multiple nodes.
  # The command to send is passed as a Command Object.
  # This implementation of an XMPP communicator uses the OmfCommandObject 
  # class as the cmdType of the Command Object
  # (see OmfCommandObject in omf-common package for more details)
  #
  # - cmdObj = the Command Object to format and send
  #
  # Refer to OmfCommandObject for a full description of the Command Object
  # parameters.
  #
  def sendCmdObject(cmdObj)
    msg = cmdObj.to_xml
    send!(msg)
  end
      
  private
     
  #
  # Subscribe to some PubSub nodes (i.e. nodes = groups = message boards)
  #
  # - groups = an Array containing the name (Strings) of the group to subscribe to
  #
  def join_groups (groups)
    
    toAdd = Array.new
    
    # Subscribe to a particular PubSub Group
    if groups.kind_of?(String)
      toAdd << groups
    # Subscribe to a list of PubSub sub-Groups under the Experiment Group
    elsif groups.kind_of?(Array)
      if (@@psGroupExperiment == nil)
        error "Tried to join a list of PubSub group, but the Experiment ID has not been set yet!"
	return false
      else
        groups.each { |g| toAdd << "#{@@psGroupExperiment}/#{g.to_s}" }
      end
    else
      error "Unknown cmdType of PubSub groups to join!"
      return false
    end

    # Now subscribe to all the PubSub groups 
    toAdd.each { |psGroup|
      if @@service.join_pubsub_node(psGroup)
        debug "Subscribed to PubSub node: '#{psGroup}'"
	return true
      else
        error "Failed to subscribe to PubSub node: '#{psGroup}'"
	return false
      end
    }
  end
      
  #
  # Send a message to the EC
  #
  # - seqNo = sequence number of the message to send
  # - msgArray = the array of text to send
  #
  def send!(message)
    # Sanity checks...
    if (message == nil) || (message.length == 0) 
      error "send! - detected attempt to send an empty message"
      return
    end
    # Build Message  
    item = Jabber::PubSub::Item.new
    msg = Jabber::Message.new(nil, message)
    item.add(msg)

    # Send it
    dst = "#{@@psGroupExperiment}/#{@@myName}"
    debug("Send (#{dst}) - msg: '#{message}'")
    begin
      @@service.publish_to_node("#{dst}", item)        
    rescue Exception => ex
      error "Failed sending to '#{dst}' - msg: '#{message}' - error: '#{ex}'"
    end
  end
      
  #
  # Process an incoming message from the EC. This method is called by the
  # callback hook, which was set up in the 'start' method of this Communicator.
  # First, we parse the message to extract the command and its arguments.
  # Then, we check if this command should trigger some Communicator-specific actions.
  # Finally, we pass this command up to the Node Agent for further processing.
  # The Payload of the received message should be an XML representation of an 
  # OMF Command Object
  #
  # - event:: [Jabber::PubSub::Event], and XML message send by XMPP server
  #
  def execute_command (event)
    begin
      # Ignore this 'event' if it doesnt have any 'items' element
      # These are notification messages from the PubSub server
      return if event.first_element("items") == nil

      # Retrieve the incoming PubSub Group of this message 
      incomingPubSubNode =  event.first_element("items").attributes['node']

      # Retrieve the Command Object from the received message
      eventBody = event.first_element("items").first_element("item").first_element("message").first_element("body")
      xmlMessage = nil
      eventBody.each_element { |e| xmlMessage = e }
      cmdObj = OmfCommandObject.new(xmlMessage)

      # Sanity checks...
      if VALID_RC_COMMANDS.include?(cmdObj.cmdType)
        #debug "Command from a Resource Controller (cmdType: '#{cmdObj.cmdType}') - ignoring it!" 
        return
      end
      if !VALID_EC_COMMANDS.include?(cmdObj.cmdType)
        debug "Unknown command cmdType: '#{cmdObj.cmdType}' - ignoring it!" 
        return
      end
      targets = cmdObj.target.split(' ') # There may be multiple space-separated targets
      isForMe = false
      targets.each { |t| isForMe = true if NodeAgent.instance.agentAliases.include?(t) }
      if !isForMe
        debug "Unknown command target: '#{cmdObj.target}' - ignoring it!" 
        return
      end

      debug "Received (#{incomingPubSubNode}) - '#{xmlMessage.to_s}'"
      # Some commands need to trigger actions on the Communicator level
      # before being passed on to the Resource Controller
      begin
        case cmdObj.cmdType
        when :ENROLL
          # Subscribe to the Experiment PubSub group 
          # and the Node's PubSub group under the experiment
	  if !NodeAgent.instance.enrolled
            @@expID = cmdObj.expID
            debug "Experiment ID: '#{@@expID}'"
	    @@psGroupExperiment = "#{@@psGroupSlice}/#{@@expID}"
            if !join_groups(@@psGroupExperiment) || !join_groups("#{@@psGroupExperiment}/#{@@myName}") 
              error "Failed to Process ENROLL command!"
              error "Maybe this is an ENROLL from a previous experiment, thus ignoring it!"
              return
            end
          end
        when :ALIAS
          join_groups(cmdObj.name.split(' '))
        when :NOOP
          return # NOOP is not sent to the Resource Controller
        end
      rescue Exception => ex 
        error "Failed to process XML message: '#{xmlMessage}' - Error: '#{ex}'"
      end

      # Now pass this command to the Resource Controller
      NodeAgent.instance.execCommand(cmdObj)
      return

    rescue Exception => ex
      error "Unknown incoming message: '#{xmlMessage.to_s}' - Error: '#{ex}'"
      error "(Received on '#{incomingPubSubNode}')" 
      return
    end
  end

end #class
