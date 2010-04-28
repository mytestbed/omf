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

module AgentCommands


  #
  # Process 'OK' reply from the RC
  #
  # - controller = the instance of this EC
  # - communicator = the instance of this EC's communicator
  # - reply = the reply to process
  #
  def AgentCommands.OK(controller, communicator, reply)
    MObject.debug("agentcmds", "OK from: '#{command.target}' - "+
                  "cmd: '#{command.cmd}' - msg: '#{command.message}'")
  end

  #
  # Process 'ENROLLED' reply from the RC
  # The EC receives such a message when a RC has enrolled in a group for this
  # experiment.
  #
  # - controller = the instance of this EC
  # - communicator = the instance of this EC's communicator
  # - reply = the reply to process
  #
  def AgentCommands.ENROLLED(controller, communicator, reply)
    sender = Node[reply.target]
    # when we receive the first ENROLLED, send a NOOP message to the RC. 
    # This is necessary since if RC is reset or restarted, it might
    # receive the last ENROLL command again, depending on the kind of 
    # transport being used. In any case, sending a NOOP would prevent this.
    communicator.send_noop(reply.target) if !sender.isUp
    sender.enrolled(reply)
  end

  #
  # Process 'WARN' reply from the RC
  # The EC receives such a message when a RC sends a warning text.
  #
  # - controller = the instance of this EC
  # - communicator = the instance of this EC's communicator
  # - reply = the reply to process
  #
  def AgentCommands.WARN(controller, communicator, reply)
    sender = Node[reply.target]
    MObject.warn("agentcmds", "sender: '#{reply.target}' ('#{sender}') - "+
                 "msg: '#{reply.message}'")
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
  # - controller = the instance of this EC
  # - communicator = the instance of this EC's communicator
  # - reply = the reply to process
  #
  def AgentCommands.WRONG_IMAGE(controller, communicator, reply)
    sender = Node[reply.target]
    MObject.debug("agentcmds", "WRONG_IMAGE from: '#{reply.target}' - "+
                  "Desired: '#{sender.image}' - Installed: '#{reply.image}'")
    sender.reset()
  end

  #
  # Process 'APP_EVENT' command from the RC 
  # The EC receives such a message when a RC reports an application-specific 
  # event that happened on the node.
  #
  # - controller = the instance of this EC
  # - communicator = the instance of this EC's communicator
  # - command = the command to process
  #
  def AgentCommands.APP_EVENT(controller, communicator, command)
    sender = Node[command.target]
    eventName = command.value
    appId = command.appID
    message = command.message
    MObject.debug("agentcmds", "APP_EVENT #{eventName} from: '#{appId}' "+
                  "(#{sender}) - msg: '#{message}'")
    sender.onAppEvent(eventName, appId, message)
    return nil
  end

  #
  # Process 'DEV_EVENT' command from the RC  
  # The EC receives such a message when a RC reports a device-specific
  # event that happened on the node.
  #
  # - controller = the instance of this EC
  # - communicator = the instance of this EC's communicator
  # - command = the command to process
  #
  def AgentCommands.DEV_EVENT(controller, communicator, command)
    sender = Node[command.target]
    eventName = command.value
    devName = command.appID
    message = command.message
    MObject.debug("agentcmds", "DEV_EVENT #{eventName} from: '#{devName}' "+
                  "(#{sender}) - msg: '#{message}'")
    sender.onDevEvent(eventName, devName, message)
    return nil
  end

  #
  # Process 'ERROR' reply from the RC
  # The EC receives such a message when a RC reports a error 
  # event that happened on the node.
  #
  # - controller = the instance of this EC
  # - communicator = the instance of this EC's communicator
  # - reply = the reply to process
  #
  def AgentCommands.ERROR(controller, communicator, reply)
    sender = Node[reply.target]
    command = reply.cmd
    case command
      when 'CONFIGURE'
        path = reply.path
        reason = "Couldn't configure '#{path}'"
        message = reply.message
        id = controller.logError(sender, reason, {:details => message})
        sender.configure(path.split("/"), reason, "error")
        MObject.error("agentcmds", "CONFIGURE ERROR '#{path}' on '#{sender}' "+
                      "- msg: #{message}")
      when 'LOST_HANDLER'
        MObject.error("agentcmds", "LOST HANDLER ERROR", "'#{sender}' lost us")
      when 'EXECUTE'
        message = reply.message
        app = reply.appID
        MObject.error("agentcmds", "EXECUTION ERROR on '#{sender}' - "+
                      "App: '#{app}'- msg: #{message}")
      else
        reason = "Unknown error caused by '#{command}'"
        message =  reply.message
        controller.logError(sender, reason, {:details => message})
        MObject.error("agentcmds", "UNKNOWN_ERROR on '#{sender}' - "+
                      "cmd: '#{command}' - msg: #{message}")
    end
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
  # - controller = the instance of this EC
  # - communicator = the instance of this EC's communicator
  # - command = the command to process
  #
  def AgentCommands.END_EXPERIMENT(controller, communicator, command)
    sender = Node[command.target]
    if controller.disconnectionMode?
      sender.setReconnected()
      info "Received End of Experiment from node '#{sender}' (reconnected)." 
      if Node.allReconnected?
        info "All nodes are now reconnected."
        Experiment.done
      else
        info "Still some nodes not reconnected"
      end
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

end
