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
# This file implements a Publish/Subscribe Communicator for the Resource Manager.
# This PubSub communicator is based on XMPP. 
# This current implementation uses the library XMPP4R.
#
#
require "omf-common/omfPubSubService"
require "omf-common/omfCommandObject"

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Resource Manager (RM) will use this Communicator to send/receive messages 
# to/from other OMF entities. 
# This Communicator is based on the Singleton design pattern.
#
class XMPPCommunicator < MObject

  DOMAIN = "OMF"
  SYSTEM = "system"
  PING_INTERVAL = 3600
  RETRY_INTERVAL = 10

  VALID_RM_COMMANDS = Set.new [:CREATE_SLIVER]

  VALID_RM_REPLIES = Set.new [:SLIVER_CREATED] 

  include Singleton
  @@instantiated = false
    
  #
  # Return the Instantiation state for this Singleton
  #
  # [Return] true/false
  #
  def XMPPCommunicator.instantiated?
    return @@instantiated
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
  # Create a new Communicator 
  #
  def initialize ()
    @@myName = ResourceManager.managerName
    @@service = nil
    @@IPaddr = nil
    @@systemNode = nil

    @@instantiated = true
    @queue = Queue.new
    Thread.new {
      while event = @queue.pop
        execute_command(event)
      end
    }
    start(ResourceManager.instance.config[:comm][:xmpp_server])
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

    # Check if PubSub Server is reachable
    check = false
    while !check
      reply = `ping -c 1 #{jid_suffix}`
      if $?.success?
        check = true
      else
        info "Could not resolve or contact: '#{jid_suffix}' - Waiting #{RETRY_INTERVAL} sec before retrying..."
        sleep RETRY_INTERVAL
      end
    end

    # Create a Service Helper to interact with the PubSub Server
    begin
      @@service = OmfPubSubService.new("OMF-RES-MGR-#{@@myName}", "123", jid_suffix)
      # Start our Event Callback, which will process Events from
      # the nodes we will subscribe to
      @@service.add_event_callback { |event|
        @queue << event
      }
    rescue Exception => ex
      error "Failed to create ServiceHelper for PubSub Server '#{jid_suffix}' - Error: '#{ex}'"
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

    # Set our PubSub group
    @@myPubSubGroup = "#{DOMAIN}/#{SYSTEM}/#{@@myName}"
  end

  #
  # Reset this Communicator
  #
  def reset
    # Leave all Pubsub nodes that we might have joined previously 
    @@service.leave_all_pubsub_nodes
    # Re-subscribe to the '/OMF/system/' Pubsub group for this node
    while (!@@service.join_pubsub_node(@@myPubSubGroup))
       debug "PubSub group '#{@@myPubSubGroup}' does not exist on the server - retrying in #{RETRY_INTERVAL} sec"
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
  # Send a message to the a PubSub group
  #
  # - message = the message send, typically a Command Object
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
    dst = "#{@@myPubSubGroup}"
    debug("Send (#{dst}) - msg: '#{message}'")
    begin
      @@service.publish_to_node("#{dst}", item)        
    rescue Exception => ex
      error "Failed sending to '#{dst}' - msg: '#{message}' - error: '#{ex}'"
    end
  end
      
  #
  # Process an incoming message on our PubSub group. This method is called by the
  # callback hook, which was set up in the 'start' method of this Communicator.
  # First, we parse the message to extract the command and its arguments.
  # Then, we check if this command should trigger some Communicator-specific actions.
  # Finally, we pass this command up to the Resource Manager for further processing.
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
      if VALID_RM_REPLIES.include?(cmdObj.cmdType)
        #debug "Command from a Resource Manager (cmdType: '#{cmdObj.cmdType}') - ignoring it!" 
        return
      end
      if !VALID_RM_COMMANDS.include?(cmdObj.cmdType)
        debug "Unknown command cmdType: '#{cmdObj.cmdType}' - ignoring it!" 
        return
      end
      if cmdObj.target != ResourceManager.managerName
        debug "Unknown command target: '#{cmdObj.target}' - ignoring it!" 
        return
      end

      debug "Received (#{incomingPubSubNode}) - '#{xmlMessage.to_s}'"
      # Some commands need to trigger actions on the Communicator level
      # before being passed on to the Resource Manager
      #begin
      #  case cmdObj.cmdType
      #  when :ENROLL
      #  when :ALIAS
      #  end
      #rescue Exception => ex 
      #  error "Failed to process XML message: '#{xmlMessage}' - Error: '#{ex}'"
      #end

      # Now pass this command to the Resource Manager
      ResourceManager.instance.execCommand(cmdObj)
      return

    rescue Exception => ex
      error "Unknown incoming message: '#{xmlMessage.to_s}' - Error: '#{ex}'"
      error "(Received on '#{incomingPubSubNode}')" 
      return
    end
  end

end #class
