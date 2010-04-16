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
    if !@@sliceID || !@@expID || !@@myName
      raise "Cannot send a command because Slice, ExpID, or Node Name are nil!"
    end
    cmdObj.sliceID = @@sliceID
    cmdObj.expID = @@expID
    msg = cmdObj.to_xml
    send(msg, my_node, :slice)
  end
  
  
  
  #
  # Send a heartbeat back to the EC
  #
  def sendHeartbeat()
    send!(0, :HB, -1, -1, -1, -1)
  end

  private
     
  #
  # Subscribe to some PubSub nodes (i.e. nodes = groups = message boards)
  #
  # - groups = an Array containing the name (Strings) of the group to subscribe to
  #
  def join_groups(groups)
    toAdd = Array.new
    # Subscribe to a particular PubSub Group
    if groups.kind_of?(String)
      toAdd << groups
    # Subscribe to a list of PubSub sub-Groups under the Experiment Group
    elsif groups.kind_of?(Array)
      if (@@expID == nil)
        error "Tried to join a list of PubSub group, but the Experiment ID"+
	      " has not been set yet!"
	return false
      else
        groups.each { |g| toAdd << "#{exp_node(@@sliceID,@@expID)}/#{g.to_s}" }
      end
    else
      error "Unknown type of PubSub node to join!"
      return false
    end
    # Now subscribe to all the PubSub groups 
    toAdd.each { |psGroup|
      if @@xmppServices.join_pubsub_node(psGroup, :slice)
        debug "Subscribed to PubSub node: '#{psGroup}'"
	return true
      else
        error "Failed to subscribe to PubSub node: '#{psGroup}'"
	return false
      end
    }
  end
      
      

  def execute_transport_specific(cmdObject)
      # Some commands need to trigger actions on the Communicator level
      # before being passed on to the Resource Controller
      begin
        case cmdObject.cmdType
        when :ENROLL
          # Subscribe to the Experiment PubSub group 
          # and the Node's PubSub group under the experiment
	  if !NodeAgent.instance.enrolled
            @@expID = cmdObject.expID
            debug "Experiment ID: '#{@@expID}'"
            if !join_groups(exp_node(@@sliceID, @@expID)) || 
	       !join_groups(my_node) 
              error "Failed to Process ENROLL command!"
              error "Maybe this is an ENROLL from an old experiment - ignoring it!"
              return
            end
	  else
	    debug "Received ENROLL, but I am already ENROLLED! - ignoring it!"
	    return
          end
        when :ALIAS
          join_groups(cmdObject.name.split(' '))
        when :NOOP
          return # NOOP is not sent to the Resource Controller
        end
      rescue Exception => ex 
        error "Failed to execute transport-specific tasks for command: "+
              "'#{cmdObject.to_s}'"
        error "Error: '#{ex}'"
      end
  end

end #class
