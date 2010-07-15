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
# = agentCommands.rb
#
# == Description
#
# During the experiment execution, the various Node Agent(s) (NA) send
# messages back to the Node Handler (EC). This module contains the methods 
# used by the (EC) to process the commands inside these messages.
#

require 'omf-expctl/nodeHandler'

module AgentCommands

  #
  # Process 'OK' reply from the RC
  #
  # - communicator = the instance of this EC's communicator
  # - reply = the reply to process
  #
  def AgentCommands.OK(communicator, reply)
    sender = Node[reply.target]
    okReason = reply.reason
    message = reply.message
    case okReason
      when 'ENROLLED'
        # when we receive the first ENROLLED, send a NOOP message to the RC. 
        # This is necessary since if RC is reset or restarted, it might
        # receive the last ENROLL command again, depending on the kind of 
        # transport being used. In any case, sending a NOOP would prevent this.
        communicator.send_noop(reply.target) if !sender.isUp
        sender.enrolled(reply)
      when 'CONFIGURED'
	# Reports the good news to our resource object
        sender.configure(reply.path.split("/"), reply.value, "CONFIGURED.OK")
        # HACK!!! Start
        # while we wait for a better device handling...
        if reply.macaddr 
	  path = reply.path.split("/")
	  path[-1] = "mac"
          sender.configure(path, reply.macaddr, "CONFIGURED.OK")
        end
        # HACK!!! End
      when 'DISCONNECT_READY'
        MObject.info("#{sender}", "Ready to be disconnected")
      else 
        MObject.debug("AgentCommands", "OK from: '#{sender}' - "+
                      "cmd: '#{okReason}' - msg: '#{message}'")
    end
  end

  #
  # Process 'WARN' reply from the RC
  # The EC receives such a message when a RC sends a warning text.
  #
  # - communicator = the instance of this EC's communicator
  # - reply = the reply to process
  #
  def AgentCommands.WARN(communicator, reply)
    sender = Node[reply.target]
    MObject.warn("AgentCommands", "sender: '#{reply.target}' ('#{sender}') - "+
                 "msg: '#{reply.message}'")
  end

  #
  # Process 'APP_EVENT' command from the RC 
  # The EC receives such a message when a RC reports an application-specific 
  # event that happened on the node.
  #
  # - communicator = the instance of this EC's communicator
  # - command = the command to process
  #
  def AgentCommands.APP_EVENT(communicator, command)
    sender = Node[command.target]
    eventName = command.value
    appId = command.appID
    message = command.message
    MObject.debug("AgentCommands", "APP_EVENT #{eventName} from: '#{appId}' "+
                  "(#{sender}) - msg: '#{message}'")
    sender.onAppEvent(eventName, appId, message)
    return nil
  end

  #
  # Process 'DEV_EVENT' command from the RC  
  # The EC receives such a message when a RC reports a device-specific
  # event that happened on the node.
  #
  # - communicator = the instance of this EC's communicator
  # - command = the command to process
  #
  def AgentCommands.DEV_EVENT(communicator, command)
    sender = Node[command.target]
    eventName = command.value
    devName = command.appID
    message = command.message
    MObject.debug("AgentCommands", "DEV_EVENT #{eventName} from: '#{devName}' "+
                  "(#{sender}) - msg: '#{message}'")
    sender.onDevEvent(eventName, devName, message)
    return nil
  end

  #
  # Process 'ERROR' reply from the RC
  # The EC receives such a message when a RC reports a error 
  # event that happened on the node.
  #
  # - communicator = the instance of this EC's communicator
  # - reply = the reply to process
  #
  def AgentCommands.ERROR(communicator, reply)
    sender = Node[reply.target]
    errorReason = reply.reason
    message = reply.message
    lines = Array.new
    case errorReason
      when 'FAILED_CONFIGURE'
	reason = "Couldn't configure '#{reply.path}'"
        NodeHandler.instance.logError(sender, reason, {:details => message})
        sender.configure(reply.path.split("/"), reason, "CONFIGURED.ERROR")
        lines << "The resource '#{sender}' reports that it failed to configure "
        lines << "the path '#{reply.path}'"
        lines << "The error message is '#{message}'" if message
      when 'WRONG_IMAGE'    
        lines << "The resource '#{sender}' reports that it has the disk image"
        lines << "'#{reply.image}' while the desired image is '#{sender.image}'"
        lines << "The resource will now reset and attempt to install the "
        lines << "required disk image."
        sender.reset()
      when 'LOST_HANDLER'
        lines << "The resource '#{sender}' lost contact with us"
      when 'EXECUTE'
        lines << "The resource '#{sender}' reports that it failed to execute"
        lines << "the application '#{reply.appID}'"
        lines << "The error message is '#{message}'" if message
      else
        NodeHandler.instance.logError(sender,
                            "Unknown error caused by '#{errorReason}'", 
                            {:details => message})
        lines << "The resource '#{sender}' reports an unknown error while"
        lines << "executing a command. Error type is '#{errorReason}'."
        lines << "The error message is '#{message}'" if message
    end
    NodeHandler.instance.display_error_msg(lines)
  end

  #
  # Process 'END_EXPERIMENT' command from the RC
  # The EC receives such a message only when it is invoked with an experiment 
  # that support temporary disconnection of node/resource from the Control 
  # Network. In such case, after distributing the experiment description 
  # directly to the RC(s), the EC enters a waiting state, where it waits for 
  # the RC(s) to report the end of the experiment.
  # Thus a given RC sends this message to the EC when it has finished executing 
  # the tasks describes in the experiment script for its particular nodes, AND 
  # when this node is reconnected to the Control Network after a temporary 
  # disconnection. The EC will wait for an 'END_EXPERIMENT' from all the nodes 
  # involved in an experiment before declaring that the experiment is indeed 
  # completed.
  #
  # - communicator = the instance of this EC's communicator
  # - command = the command to process
  #
  def AgentCommands.END_EXPERIMENT(communicator, command)
    sender = Node[command.target]
    if Experiment.disconnection_allowed? 
      MObject.info("#{sender}", 
                   "Received End of Experiment from resource '#{sender}'")
      sender.reconnected = true
      #if Node.allReconnected?
      #  info "All nodes are now reconnected."
      #  Experiment.done
      #else
      #  info "Still some nodes not reconnected"
      #end
    end 
  end

  #
  # Process 'HB' message from a Node Agent. 
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - cmdObj = an OmfCommandObject holding the information for this command
  #
  def AgentCommands.HB(communicator, cmdObj)
    sender = Node[cmdObj.target]
    sender.heartbeat(0, 0, "00:00")
  end
  
  #
  # Process 'WRONG_IMAGE' reply from the RC
  # The EC receives such a message when a RC has an installed disk image which 
  # is different from the one requested in the experiment description
  # For now, the EC reset/reboot that node, and tries to enroll it again. When
  # called within a LOAD experiment, this would trigger pxe booting and image 
  # loading.
  # (in the future, the EC should request AM to install the correct image)
  #
  # Note: This assumes that the communication scheme that this OMF deployment
  # uses is actually keeping the last message addressed to a group for every 
  # new meember of that group (i.e. subscribers). Thus there is no need to 
  # send this enrolling message again. 
  # If the underlying communication scheme does not have this behaviour, then 
  # another enroll sequence will need to be started here.
  #
  # - communicator = the instance of this EC's communicator
  # - reply = the reply to process
  #
  #def AgentCommands.WRONG_IMAGE(communicator, reply)
  #  sender = Node[reply.target]
  #  MObject.debug("AgentCommands", "WRONG_IMAGE from: '#{reply.target}' - "+
  #                "Desired: '#{sender.image}' - Installed: '#{reply.image}'")
  #  sender.reset()
  #end

end
