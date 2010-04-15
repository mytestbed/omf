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
    #
    # NOTE IMPORTANT
    #
    # For now, we assume that the Home PubSub Server is always the one that will
    # host the PubSub node for our Slice and Experiments.
    # This should be explicitely mentioned in the EC install/user guide, i.e.
    # your EC's Home PubSub Server will also be the one that will host your
    # Slice and Experiment PubSub tree
    #
    @@xmppServices.add_service_alias(:home, :slice)
  end
      
  def connect(user, pwd, server)
    # Now call our superclass method to do the actual 'connect'
    super(user, pwd, server)

    # Some EC-specific post-connection tasks...
    # 1st make sure that there is no old pubsub nodes lingering
    begin
      @@xmppServices.remove_all_pubsub_nodes(:slice)
    rescue Exception => ex
      error "Failed to remove old PubSub nodes"
      error "Error: '#{ex}'"
      error "Most likely reason: Cannot contact PubSub Server '#{@@homeServer}'"
      error "Exiting!"
      exit
    end
    # 2nd create a new pubsub node for this experiment
    @@service.create_pubsub_node(exp_node(@@sliceID, @@expID), :slice)

    #@@psGroupSlice = "/#{DOMAIN}/#{@@sliceID}" # ...created @ slice 
    #@@psGroupResource = "#{@@psGroupSlice}/#{RESOURCE}" # ...created @ slice 
    #@@psGroupExperiment = "#{@@psGroupSlice}/#{@@expID}"
  end
 
  #
  # This method is called when the experiment is finished or cancelled
  #
  def stop
    @@xmppServices.remove_all_pubsub_nodes(:slice)
    @@xmppServices.stop
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
  def send_command(cmdObj)
    cmdObj.sliceID = @@sliceID
    cmdObj.expID = @@expID
    target = cmdObj.target
    cmdType = cmdObj.cmdType
    msg = cmdObj.to_xml

    # Some commands need to trigger actions on the Communicator level
    # before being sent to the Resource Controllers
    case cmdType
    when :ENROLL
      # 1st create the pubsub node for this resource under the Experiment branch
      # (so that the resource can subscribe to it after receiving the ENROLL)
      newPubSubNode = "#{exp_node(@@sliceID, @@expID)}/#{target}"
      @@xmppServices.create_pubsub_node(newPubSubNode, :slice)
      # 2nd send the message to the Resource branch of the Slice branch
      send(msg, res_node(@@sliceID,target), :slice)
      return
    when :NOOP
      # NOOP is also sent to the Resource branch of the Slice branch
      send(msg, res_node(@@sliceID,target), :slice)
      return
    when :ALIAS
      # create the pubsub group for this alias 
      newPubSubNode = "#{exp_node(@@sliceID, @@expID)}/#{cmdObj.name}"
      @@xmppServices.create_pubsub_node(newPubSubNode, :slice)
    end
	    
    # Now send this command to the relevant PubSub Node in the Experiment branch
    if (target == "*")
      send(msg, exp_node(@@sliceID, @@expID), :slice)
    else
      targets = target.split(' ')
      targets.each {|tgt|
        send(msg, "#{exp_node(@@sliceID, @@expID)}/#{tgt}", :slice)
      }
    end
  end

  #
  # This sends a NOOP to the resource's node to overwrite the last buffered 
  # ENROLL message
  #
  # - name = name of the node to receive the NOOP
  #
  def send_noop(name)
    noop_cmd = new_command(:NOOP)
    noop_cmd.target = name
    send_command(noop_cmd)
  end

  private
         
  def valid_command?(cmdObject)

    # Perform some checking...
    # - Ignore commands from ourselves or another EC
    return false if cmdObject.ec_cmd?
    # - Ignore commands that are not known RC commands
    if !cmdObject.rc_cmd?
      debug "Received unknown command '#{cmdObject.cmdType}' - ignoring it!" 
      return false
    end
    # - Ignore commands for/from unknown Slice and Experiment ID
    if (cmdObject.sliceID != @@sliceID) || (cmdObject.expID != @@expID)
      debug "Received command with unknown slice and exp IDs: "+
            "'#{cmdObject.sliceID}' and '#{cmdObject.expID}' - ignoring it!" 
      return false
    end
    # - Ignore commands from unknown RCs
    if (Node[cmdObject.target] == nil)
      debug "Received command with unknown target '#{cmdObject.target}'"+
            " - ignoring it!"
      return false
    end
    return true
  end
    
  def execute_transport_specific(cmdObject)
    # Some commands need to trigger actions on the Communicator level
    # before being passed on to the Experiment Controller
    begin
      case cmdObject.cmdType
      when :ENROLLED
        # when we receive the first ENROLL, send a NOOP message to the NA. 
        # This is necessary since if NA is reset or restarted, it would 
        # re-subscribe to its system PubSub node and would receive the last 
        # command sent via this node (which is ENROLL if we don't send NOOP)
        # from the PubSub server (at least openfire works this way). It would 
        # then potentially try to subscribe to nodes from a past experiment.
        send_noop(cmdObject.target) if !Node[cmdObject.target].isUp
      end
    rescue Exception => ex 
      error "Failed to execute transport-specific tasks for command: "+
            "'#{cmdObject.to_s}'"
      error "Error: '#{ex}'"
      return
    end
  end

end #class
