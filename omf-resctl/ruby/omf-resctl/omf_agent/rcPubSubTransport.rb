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
require "omf-common/omfPubSubTransport"
require "omf-common/omfCommandObject"

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Node Agent (NA) aka Resource Controller will use this Communicator to 
# send/receive messages to/from the Node Handler (EC) aka Experiment Controller
# This Communicator is based on the Singleton design pattern.
#
class RCPubSubTransport < OMFPubSubTransport

  def self.init(comms, opts, slice, name)
    super()
    # So RC-specific initialisation tasks...
    @@communicator = comms
    @@myName = name
    @@sliceID = slice
    @@homeServer = opts[:home_pubsub_server]
    @@remoteServer = opts[:remote_pubsub_server]
    if !@@homeServer || !@@remoteServer
      raise "RCPubSubTransport - Missing 'home_pubsub_server' or "+
            "'remote_pubsub_server' parameter in the RC configuration" 
    end
    user = opts[:home_pubsub_user] || "#{@@myName}-#{@@sliceID}-#{@@expID}"
    pwd = opts[:home_pubsub_pwd] || DEFAULT_PUBSUB_PWD
    # Now connect to the Home PubSub Server
    @@instance.connect(user, pwd, @@homeServer)
    # If the PubSub nodes for our slice is hosted on a Remote PubSub Server
    # and not on our Home one, then we need to add another PubSub service to 
    # interact with this remote server
    #
    # TODO: IF not we need to do :slice = :home (FIXME)
    #
    if @@homeServer != @@remoteServer
      @@xmppServices.add_new_service(:slice, @@remoteServer) { |event|
        @@queue << event
      }         
    else
  end
  
  def connect(user, pwd, server)
    # Some RC-specific pre-connection tasks...
    # first checks if PubSub Server is reachable, and wait/retry if not
    check_server_reachability(server)
    
    # Now call our superclass method to do the actual 'connect'
    super(user, pwd, server)

    # Some RC-specific post-connection tasks...
    # Keep the connection to the PubSub server alive by sending a ping at
    # regular intervals hour, otherwise clients will be listed as "offline" 
    # by the PubSub server (e.g. Openfire) after a timeout
    Thread.new do
      while true do
        sleep PING_INTERVAL
        debug("Sending a ping to the Home PubSub Server (keepalive)")
        @@xmppServices.ping(:home)        
      end
    end

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
  def start(opts)
    # Open a connection to the Home PubSub Server
    begin
      debug "Connecting to PubSub Server '#{@@homeServer}' as user '#{user}'"
      @@xmppServices = OmfXMPPServices.new(expID, password, @@homeServer)
      # Start our Event Callback, which will process Events from
      # the nodes we will subscribe to
      @@service.add_event_callback { |event|
        @queue << event
      }
    rescue Exception => ex
      error "Failed to initialise PubSub service! - Error: '#{ex}'"
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
  # Create a new Communicator 
  #
  def initialize ()
    @@service = nil
    @@IPaddr = nil
    @@systemNode = nil
    @@expID = nil
    @@psGroupSlice = nil
    @@psGroupResource = nil
    @@psGroupExperiment = nil

    start(NodeAgent.instance.config[:comm])
    #start(NodeAgent.instance.config[:comm][:xmpp_server])
  end
  

  #
  # Reset this Communicator
  #
  def reset
    @@expID = nil
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
    cmdObj.sliceID = @@sliceID
    cmdObj.expID = @@expID
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
      # CHECK - Ignore this 'event' if it doesnt have any 'items' element
      # These are notification messages from the PubSub server
      return if event.first_element("items") == nil
      return if event.first_element("items").first_element("item") == nil

      # Retrieve the incoming PubSub Group of this message 
      incomingPubSubNode =  event.first_element("items").attributes['node']

      # Retrieve the Command Object from the received message
      eventBody = event.first_element("items").first_element("item").first_element("message").first_element("body")
      xmlMessage = nil
      eventBody.each_element { |e| xmlMessage = e }
      # CHECK - Ignore events without XML payloads
      return if xmlMessage == nil 
      cmdObj = OmfCommandObject.new(xmlMessage)

      # CHECK - Ignore commands from ourselves or another RC
      if VALID_RC_COMMANDS.include?(cmdObj.cmdType)
        #debug "Command from a Resource Controller (cmdType: '#{cmdObj.cmdType}') - ignoring it!" 
        return
      end
      # CHECK - Ignore commands that are not known EC commands
      if !VALID_EC_COMMANDS.include?(cmdObj.cmdType)
        debug "Received command with unknown type: '#{cmdObj.cmdType}' - ignoring it!" 
        return
      end
      # CHECK - Ignore commands for/from unknown Slice and Experiment ID
      if (cmdObj.cmdType != :ENROLL) && ((cmdObj.sliceID != @@sliceID) || (cmdObj.expID != @@expID))
        debug "Received command with unknown slice/exp IDs: '#{cmdObj.sliceID}'/'#{cmdObj.expID}' - ignoring it!" 
        return
      end
      # CHECK - Ignore commands that are not address to us 
      targets = cmdObj.target.split(' ') # There may be multiple space-separated targets
      isForMe = false
      targets.each { |t| isForMe = true if NodeAgent.instance.agentAliases.include?(t) }
      if !isForMe
        debug "Received command with unknown target: '#{cmdObj.target}' - ignoring it!" 
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
