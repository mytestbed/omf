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


  private
         
    

end #class
