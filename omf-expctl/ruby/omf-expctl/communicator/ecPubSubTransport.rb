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
require "omf-common/omfPubSubTransport"
require "omf-common/omfCommandObject"

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Node Agent (NA) aka Resource Controller will use this Communicator to 
# send/receive messages to/from the Node Handler (EC) aka Experiment Controller
# This Communicator is based on the Singleton design pattern.
#
class ECPubSubTransport < OMFPubSubTransport

  def self.init(comms, opts, slice, expID)
    super()
    # So EC-specific initialisation tasks...
    @@communicator = comms
    @@expID = expID
    @@sliceID = slice
    @@homeServer = opts[:home_pubsub_server]
    if !@@homeServer
      raise "ECPubSubTransport - Missing 'home_pubsub_server' parameter in "+
            "the EC configuration" 
    end
    user = opts[:home_pubsub_user] || "EC-#{@@sliceID}-#{@@expID}"
    pwd = opts[:home_pubsub_pwd] || DEFAULT_PUBSUB_PWD
    # Now connect to the Home PubSub Server
    @@instance.connect(user, pwd, @@homeServer)
  end
      
  def connect(user, pwd, server)
    # Now call our superclass method to do the actual 'connect'
    super(user, pwd, server)

    # Some EC-specific post-connection tasks...
    begin
      @@service.remove_all_pubsub_nodes
    rescue Exception => ex
      error "Failed to remove old PubSub nodes"
      error "Error: '#{ex}'"
      error "Most likely reason: Cannot connect to PubSubServer: '#{jid_suffix}'"
      error "Exiting!"
      exit
    end
        
    @@psGroupSlice = "/#{DOMAIN}/#{@@sliceID}" # ...created upon slice instantiation
    @@psGroupResource = "#{@@psGroupSlice}/#{RESOURCE}" # ...created upon slice instantiation
    @@psGroupExperiment = "#{@@psGroupSlice}/#{@@expID}"
    @@service.create_pubsub_node("#{@@psGroupExperiment}")

    
  end
 

   #
  # Create a new Communicator 
  #
  def initialize ()
    super('xmppCommunicator')
    @handlerCommands = Hash.new
    @@service = nil
    @@IPaddr = nil
    @@controlIF = nil
    @@systemNode = nil
    @@psGroupSlice = nil
    @@psGroupResource = nil
    @@psGroupExperiment = nil
    @@pubsubNodePrefix = nil
  end  


  #
  # This method sends a reset message to all connected nodes
  #
  def sendReset()
    reset_cmd = getCmdObject(:RESET)
    reset_cmd.target = "*"
    sendCmdObject(reset_cmd)
  end

  #
  # This sends a NOOP to the /Domain/System/IPaddress
  # node to overwrite the last buffered YOUARE
  #
  # - name = name of the node to receive the NOOP
  #
  def sendNoop(name)
    noop_cmd = getCmdObject(:NOOP)
    noop_cmd.target = name
    sendCmdObject(noop_cmd)
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
    send!("RESET", "#{@@psGroupExperiment}/#{name}")
    @@service.remove_pubsub_node("#{@@psGroupExperiment}/#{name}")
  end

  #
  # This method adds a node to an existing/new group
  # (a node can belong to multiple groups)
  #
  # - nodeName = name of the node 
  # - groupName =  name (or an array or names) of the group(s) to add the node to
  #
  def addToGroup(nodeName, groupName)
    @@service.create_pubsub_node("#{@@psGroupExperiment}/#{groupName}")
  end

  #
  # This method is called when the experiment is finished or cancelled
  #
  def quit()
    @@service.remove_all_pubsub_nodes
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
    cmdObj.sliceID = @@sliceID
    cmdObj.expID = @@expID
    target = cmdObj.target
    cmdType = cmdObj.cmdType
    msg = cmdObj.to_xml

    # Some commands need to trigger actions on the Communicator level
    # before being sent to the Resource Controllers
    case cmdType
    when :ENROLL
      # ENROLL messages are sent to the branch psGroupResource
      # create the experiment pubsub group so the node can subscribe to it
      # after receiving the ENROLL message
      psGroup = "#{@@psGroupExperiment}/#{target}"
      @@service.create_pubsub_node(psGroup)
      send!(msg, "#{@@psGroupResource}/#{target}")
      return
    when :NOOP
      # NOOP are also sent to the branch psGroupResource
      send!(msg, "#{@@psGroupResource}/#{target}")
      return
    when :ALIAS
      # create the pubsub group for this alias 
      @@service.create_pubsub_node("#{@@psGroupExperiment}/#{cmdObj.name}")
    end
	    
    # Now send this command to the relevant PubSub group in the experiment branch
    if (target == "*")
      send!(msg, "#{@@psGroupExperiment}")
      #send!(msg.to_s, "#{@@psGroupExperiment}")
    else
      targets = target.split(' ')
      targets.each {|tgt|
        send!(msg, "#{@@psGroupExperiment}/#{tgt}")
      }
    end
  end
  
  #############################################################################################################  
  #############################################################################################################  
  #############################################################################################################
      
  private
     
  def send!(message, dst)
    # Sanity checks...
    if (message.length == 0) then
      error "send! - detected attempt to send an empty message"
      return
    end
    if (dst.length == 0 ) then
      error "send! - empty destination"
      return
    end
    # Build Message
    item = Jabber::PubSub::Item.new
    msg = Jabber::Message.new(nil, message)
    item.add(msg)
  
    # Send it
    debug("Send to '#{dst}' - msg: '#{message}'")
    begin
      @@service.publish_to_node("#{dst}", item)        
    rescue Exception => ex
      error "Failed sending to '#{dst}' - msg: '#{message}' - error: '#{ex}'"
    end
  end
      
  #
  # Process an incoming message from the EC. This method is called by the
  # callback hook, which was set up in the 'start' method of this Communicator.
  # First, we parse the PubSub event to extract the XML message.
  # Then, we check if this message contains a command which should trigger some
  # Communicator-specific actions.
  # Finally, we pass this command up to the Resource Controller for further processing.
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

      # CHECK - Ignore commands from ourselves or another EC
      if VALID_EC_COMMANDS.include?(cmdObj.cmdType) 
        return
      end
      # CHECK - Ignore commands that are not known RC commands
      if !VALID_RC_COMMANDS.include?(cmdObj.cmdType)
        debug "Received command with unknown type: '#{cmdObj.cmdType}' - ignoring it!" 
        return
      end
      # CHECK - Ignore commands for/from unknown Slice and Experiment ID
      if (cmdObj.sliceID != @@sliceID) || (cmdObj.expID != @@expID)
        debug "Received command with unknown slice/exp IDs: '#{cmdObj.sliceID}/#{cmdObj.expID}' - ignoring it!" 
        return
      end
      # CHECK - Ignore commands from unknown RCs
      if (Node[cmdObj.target] == nil)
        debug "Received command with unknown target: '#{cmdObj.target}' - ignoring it!"
        return
      end

      debug "Received on '#{incomingPubSubNode}' - msg: '#{xmlMessage.to_s}'"
      # Some commands need to trigger actions on the Communicator level
      # before being passed on to the Experiment Controller
      begin
        case cmdObj.cmdType
        when :ENROLLED
          # when we receive the first ENROLL, send a NOOP message to the NA. This is necessary
          # since if NA is reset or restarted, it would re-subscribe to its system PubSub node and
          # would receive the last command sent via this node (which is ENROLL if we don't send NOOP)
          # from the PubSub server (at least openfire works this way). It would then potentially
          # try to subscribe to nodes from a past experiment.
          sendNoop(cmdObj.target) if !Node[cmdObj.target].isUp
        end
      rescue Exception => ex 
        error "Failed to process XML message: '#{xmlMessage.to_s}' - Error: '#{ex}'"
      end

      # Now pass this command to the Resource Controller
      processCommand(cmdObj)
      return

    rescue Exception => ex
      error "Unknown/Wrong incoming message: '#{xmlMessage}' - Error: '#{ex}'"
      error "(Received on '#{incomingPubSubNode}')" 
      return
    end

  end

   #
   # This method processes the command comming from an agent
   #
   #  - argArray = command line parsed into an array
   #
   def processCommand(cmdObj)

    debug "Processing '#{cmdObj.cmdType}' - '#{cmdObj.target}'"

    # Retrieve the command
    method = nil
    begin
      method = AgentCommands.method(cmdObj.cmdType.to_s)
    rescue Exception
      error "Unknown command '#{cmdObj.cmdType}'"
      return
    end
    # Execute the command
    begin
      reply = method.call(self, Node[cmdObj.target], cmdObj)
    rescue Exception => err
      error "While processing command '#{cmdObj.cmdType}': #{err}"
      error "Trace: #{err.backtrace.join("\n")}" 
      return
    end

   end
    
end #class
