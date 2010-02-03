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
  # Process 'HB' message from a Node Agent. 
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.HB(communicator, sender, cmdObj)
    sender.heartbeat(0, 0, "00:00")
  end

  def AgentCommands.OK(communicator, sender, cmdObj)
    MObject.debug("agentCmd::OK from: '#{cmdObj.target}' - cmd: '#{cmdObj.cmd}' - msg: '#{cmdObj.message}'")
  end

  #
  # Process 'ENROLLED' message from a Node Agent. 
  # The EC receives such a message when a NA has enrolled in a group of the experiment.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.ENROLLED(communicator, sender, cmdObj)
    sender.enrolled(cmdObj)
  end


  #
  # Process 'WARN' message from a Node Agent. 
  # The EC receives such a message when a NA sends a warning text.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.WARN(communicator, sender, cmdObj)
    MObject.warn("agentCmd::WARN from: '#{cmdObj.target}' ('#{sender}') - msg: '#{cmdObj.message}'")
  end

  #
  # Process 'WRONG_IMAGE' message from a Node Agent. 
  # The EC receives such a message when a NA has an installed disk image which 
  # is different from the one requested in the experiment description
  # For now, the EC reset/reboot that node, and tries to enroll it again. When
  # called within a LOAD experiment, this would trigger pxe booting and image loading.
  # (in the future, the EC should request AM to install the correct image)
  #
  # Note: This assumes that the XMPP server is actually keeping the last message 
  # addressed to a group for every new subscribers. Thus there is no need to send 
  # enrolling message again. If XMPP standard changes or server is not having 
  # this behaviour, then a enroll process will need to be started here.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.WRONG_IMAGE(communicator, sender, cmdObj)
    MObject.debug("agentCmd::WRONG_IMAGE from: '#{cmdObj.target}' - Desired: '#{sender.image}' - Installed: '#{cmdObj.image}'")
    sender.reset()
  end

  #
  # Process 'APP_EVENT' message from a Node Agent. 
  # The EC receives such a message when a NA reports an application-specific 
  # event that happened on the node.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.APP_EVENT(communicator, sender, cmdObj)
    eventName = cmdObj.value
    appId = cmdObj.appID
    message = cmdObj.message
    MObject.debug("agentCmd::APP_EVENT #{eventName} from: '#{appId}' (#{sender}) - msg: '#{message}'")
    sender.onAppEvent(eventName, appId, message)
    return nil
  end

  #
  # Process 'DEV_EVENT' message from a Node Agent. 
  # The EC receives such a message when a NA reports a device-specific
  # event that happened on the node.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.DEV_EVENT(communicator, sender, cmdObj)
    eventName = cmdObj.value
    devName = cmdObj.appID
    message = cmdObj.message
    MObject.debug("agentCmd::DEV_EVENT #{eventName} from: '#{devName}' (#{sender}) - msg: '#{message}'")
    sender.onDevEvent(eventName, devName, message)
    return nil
  end

  #
  # Process 'APP_EVENT' message from a Node Agent. 
  # The EC receives such a message when a NA reports a error 
  # event that happened on the node.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  # When the error resulted from a previous 'CONFIGURE' message issued by the EC,
  # the argument array contains the two following fields:
  # - path  Id of resource to have been configured
  # - msg   Message describing error condition
  #
  def AgentCommands.ERROR(communicator, sender, cmdObj)
    command = cmdObj.cmd
    case command
      when 'CONFIGURE'
        path = cmdObj.path
	reason = "Couldn't configure '#{path}'"
        message = cmdObj.message
        id = NodeHandler.instance.logError(sender, reason, {:details => message})
        sender.configure(path.split("/"), reason, "error")
        MObject.error("agentCmd::CONFIGURE_ERROR '#{path}' on '#{sender}' - msg: #{message}")
      when 'LOST_HANDLER'
        MObject.error("agentCmd::LOST_HANDLER_ERROR", "'#{sender}' lost us")
      when 'EXECUTE'
        message = cmdObj.message
        app = cmdObj.appID
        MObject.error("agentCmd::EXECUTION_ERROR on '#{sender}' - App: '#{app}'- msg: #{message}")
      else
        reason = "Unknown error caused by '#{command}'"
        message =  cmdObj.message
        NodeHandler.instance.logError(sender, reason, {:details => message})
        MObject.error("agentCmd::UNKNOWN_ERROR on '#{sender}' - cmd: '#{command}' - msg: #{message}")
    end
  end

  #
  # Process 'END_EXPERIMENT' message from a Node Agent. 
  # The EC receives such a message only when it is invoked with an experiment that
  # support temporary disconnection of node/resource from the Control Network.
  # In such case, after distributing the experiment description directly to the NA(s),
  # the EC enters a waiting state, where it waits for the NA(s) to report the end of 
  # the experiment.
  # Thus a given NA sends this message to the EC when it has finished executing the 
  # tasks describes in the experiment script for its particular nodes, AND when this
  # node is reconnected to the Control Network after a temporary disconnection. 
  # The EC will wait for an 'END_EXPERIMENT' from all the nodes involved in an experiment
  # before declaring that the experiment is indeed completed.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.END_EXPERIMENT(communicator, sender, cmdObj)
    if NodeHandler.disconnectionMode?
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
  # This methods perform useful sub-routine task for the message processing commands.
  #
  # It removes the first element from 'argArray' and returns it. 
  # If it is nil, raise exception with 'excepString' providing MObject.information 
  # about the missing argument
  #
  # - argArray = Array of arguments
  # - excepString = MObject.information about argument, used for exception
  #
  # [Return] First element in 'argArray' or raise exception
  # [Raise] Exception if the first element is nil
  #
  #def AgentCommands.getArg(argArray, excepString)
  #  arg = argArray.delete_at(0)
  #  if (arg == nil)
  #    raise excepString
  #  end
  #  return arg
  #end

  #
  # This methods perform useful sub-routine task for the message processing commands.
  #
  # It removes the first element from 'argArray' and returns it. 
  # If it is nil, return 'default'
  #
  # - argArray = Array of arguments
  # - default = Default value if the first element in argArray is nil
  #
  # [Return] First element in 'argArray' or 'default' if nil
  #
  #def AgentCommands.getArgDefault(argArray, default = nil)
  #  arg = argArray.delete_at(0)
  #  if (arg == nil)
  #    arg = default
  #  end
  #  return arg
  #end

end
