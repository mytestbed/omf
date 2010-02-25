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
require "omf-common/omfCommandObject"
require 'omf-common/mobject'
require 'omf-expctl/agentCommands'

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Node Agent (NA) aka Resource Controller will use this Communicator to 
# send/receive messages to/from the Node Handler (EC) aka Experiment Controller
# This Communicator is based on the Singleton design pattern.
#
class XmppCommunicator < Communicator

  DOMAIN = "OMF"
  RESOURCE = "resources"
  VALID_EC_COMMANDS = Set.new [:EXECUTE, :KILL, :STDIN, :NOOP, 
	                :PM_INSTALL, :APT_INSTALL, :RPM_INSTALL, :RESET, 
                        :REBOOT, :MODPROBE, :CONFIGURE, :LOAD_IMAGE,
                        :SAVE_IMAGE, :LOAD_DATA, :SET_MACTABLE, :ALIAS,
                        :RESTART, :ENROLL, :EXIT]

  VALID_RC_COMMANDS = Set.new [:ENROLLED, :WRONG_IMAGE, :OK, :HB, :WARN, 
                        :APP_EVENT, :DEV_EVENT, :ERROR, :END_EXPERIMENT]

  @@instance = nil
    
  #
  # Return the Instantiation state for this Singleton
  #
  # [Return] true/false
  #
  def XmppCommunicator.instantiated?
    return @@instantiated
  end   
  
  def self.init(opts, slice, expID)
    raise "XMPPCommunicator already started" if @@instance

    server = opts[:server]
    raise "XMPPCommunicator: Missing 'server'" unless server
    password = opts[:password] || "123"
    
    @@instance = self.new()
    @@instance.start(server, password, slice, expID)
    @@instance
  end
      
  #
  # Create a new Communicator 
  #
  def initialize ()
    super('xmppCommunicator')
    @handlerCommands = Hash.new
    @@myName = nil
    @@service = nil
    @@IPaddr = nil
    @@controlIF = nil
    @@systemNode = nil
    @@expID = nil
    @@psGroupSlice = nil
    @@psGroupResource = nil
    @@psGroupExperiment = nil
    @@sliceID = nil
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
  # - jid_suffix = [String], JabberID suffix, this is the full host/domain name of 
  #                the PubSub server, e.g. 'norbit.npc.nicta.com.au'. 
  # - password = [String], password to use for this PubSud client
  # - control_interface = [String], the interface connected to Control Network
  #
  def start(jid_suffix, password, slice, expID)
    
    debug "Connecting to PubSub Server: '#{jid_suffix}'"
    # Set some internal attributes...
    @@sliceID = slice
    @@expID = expID
    
    # Create a Service Helper to interact with the PubSub Server
    begin
      @@service = OmfPubSubService.new(expID, password, jid_suffix)
      # Start our Event Callback, which will process Events from
      # the nodes we will subscribe to
      @@service.add_event_callback { |event|
        @queue << event
      }         
    rescue Exception => ex
      error "Failed to initialise PubSub service ('#{jid_suffix}')!"
      error "Error: '#{ex}'"
    end

    begin
      @@service.remove_all_pubsub_nodes
    rescue Exception => ex
      error "Failed to remove old PubSub nodes"
      error "Error: '#{ex}'"
      error "Most likely reason: Cannot connect to PubSubServer: '#{jid_suffix}'"
      error "Exiting!"
      exit!
    end
        
    @@psGroupSlice = "/#{DOMAIN}/#{@@sliceID}" # ...created upon slice instantiation
    @@psGroupResource = "#{@@psGroupSlice}/#{RESOURCE}" # ...created upon slice instantiation
    @@psGroupExperiment = "#{@@psGroupSlice}/#{@@expID}"
    @@service.create_pubsub_node("#{@@psGroupExperiment}")
    
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
      send!(msg, "#{@@psGroupExperiment}")
    else
      target.gsub!(/^"(.*?)"$/,'\1')
      targets = target.split(' ')
      targets.each {|tgt|
        send!(msg, "#{@@psGroupExperiment}/#{tgt}")
      }
    end
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
      # Ignore this 'event' if it doesnt have any 'items' element
      # These are notification messages from the PubSub server
      return if event.first_element("items") == nil
      return if event.first_element("items").first_element("item") == nil
      

      # Retrieve the incoming PubSub Group of this message 
      incomingPubSubNode =  event.first_element("items").attributes['node']

      # Retrieve the Command Object from the received message
      info "TDEBUG - EVENT - #{event.to_s}"
      eventBody = event.first_element("items").first_element("item").first_element("message").first_element("body")
      xmlMessage = nil
      eventBody.each_element { |e| xmlMessage = e }
      cmdObj = OmfCommandObject.new(xmlMessage)

      # Sanity checks...
      if VALID_EC_COMMANDS.include?(cmdObj.cmdType) # ignore command from ourselves
        return
      end
      if !VALID_RC_COMMANDS.include?(cmdObj.cmdType)
        debug "Received command with unknown type: '#{cmdObj.cmdType}' - ignoring it!" 
        return
      end
      if (Node[cmdObj.target] == nil)
        debug "Received command with unknown target: '#{cmdObj.target}' - ignoring it!"
        return
      end
      # Final check: is this command for this slice and experiment?
      if (cmdObj.sliceID != @@sliceID) || (cmdObj.expID != @@expID)
        debug "Received command with unknown slice/exp IDs: '#{cmdObj.sliceID}/#{cmdObj.expID}' - ignoring it!" 
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
