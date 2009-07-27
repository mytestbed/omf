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
# messages back to the Node Handler (NH). This module contains the methods 
# used by the (NH) to process the commands inside these messages.
#

module AgentCommands

  #
  # Process 'ENROLLED' message from a Node Agent. 
  # The NH receives such a message when a NA has enrolled for the experiment.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.HB(handler, sender, senderId, argArray)
    MObject.debug("agentCmd::enrolled", sender, ": ", sender, " senderId: ", senderId, ":" , argArray.join(','))
    sender.heartbeat(0, 0, "00:00")
  end

  #
  # Process 'WARN' message from a Node Agent. 
  # The NH receives such a message when a NA sends a warning text.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.WARN(handler, sender, senderId, argArray)
    MObject.warn("agentCmd::warning", sender, ": ", sender, " senderId: ", senderId, ":" , argArray.join(','))
  end

  #
  # Process 'APP_EVENT' message from a Node Agent. 
  # The NH receives such a message when a NA reports an application-specific 
  # event that happened on the node.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.APP_EVENT(handler, sender, senderId, argArray)
    eventName = getArg(argArray, "Name of event")
    appId = getArg(argArray, "Application ID")
    message = getArgDefault(argArray, nil)
    MObject.debug("agentCmd::APP_EVENT", eventName, "' from '", appId, \
        "' executing on ", sender, ": '", message, "'")
    sender.onAppEvent(eventName, appId, message)
    return nil
  end

  #
  # Process 'DEV_EVENT' message from a Node Agent. 
  # The NH receives such a message when a NA reports a device-specific
  # event that happened on the node.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.DEV_EVENT(handler, sender, senderId, argArray)
    eventName = getArg(argArray, "Name of event")
    devName = getArg(argArray, "Device name")
    message = getArgDefault(argArray, nil)
    MObject.debug("agentCmd::DEV_EVENT", eventName, "' from '", devName, \
        "' executing on ", sender, ": '", message, "'")
    sender.onDevEvent(eventName, devName, message)
    return nil
  end

  #
  # Process 'APP_EVENT' message from a Node Agent. 
  # The NH receives such a message when a NA reports a error 
  # event that happened on the node.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  # When the error resulted from a previous 'CONFIGURE' message issued by the NH,
  # the argument array contains the two following fields:
  # - path  Id of resource to have been configured
  # - msg   Message describing error condition
  #
  def AgentCommands.ERROR(handler, sender, senderId, argArray)
    command = getArg(argArray, "Command causing error")
    case command
      when 'CONFIGURE'
        path = getArg(argArray, "Name of resource")
        reason = "Couldn't configure '#{path}'"
        message = argArray.join(' ')
        id = NodeHandler.instance.logError(sender, reason, {:details => message})
        sender.configureStatus(path, "error", {"logRef" => id})
        MObject.error("agentCmd::CONFIGURE_ERROR", "#{reason} on '#{sender}': #{message}")
      when 'LOST_HANDLER'
        MObject.error("agentCmd::LOST_HANDLER_ERROR", "'#{sender}' lost us")
      when 'EXECUTION'
        message = argArray.join(' ')
        MObject.error("agentCmd::EXECUTION_ERROR", "Execution Error on node: '#{sender}' - Error Message: #{message}")
      else
        reason = "Unknown error caused by '#{command}'"
        message = argArray.join(' ')
        NodeHandler.instance.logError(sender, reason, {:details => message})
        MObject.error("agentCmd::UNKNOWN_ERROR", "#{reason} on '#{sender}': #{message}")
    end
  end

  #
  # Process 'END_EXPERIMENT' message from a Node Agent. 
  # The NH receives such a message only when it is invoked with an experiment that
  # support temporary disconnection of node/resource from the Control Network.
  # In such case, after distributing the experiment description directly to the NA(s),
  # the NH enters a waiting state, where it waits for the NA(s) to report the end of 
  # the experiment.
  # Thus a given NA sends this message to the NH when it has finished executing the 
  # tasks describes in the experiment script for its particular nodes, AND when this
  # node is reconnected to the Control Network after a temporary disconnection. 
  # The NH will wait for an 'END_EXPERIMENT' from all the nodes involved in an experiment
  # before declaring that the experiment is indeed completed.
  #
  # - handler = the communicator that called this method
  # - sender = the object that issued this command (i.e. usually a 'Node' object)
  # - senderId = the sender ID 
  # - argArray = an array holding the arguments for this command
  #
  def AgentCommands.END_EXPERIMENT(handler, sender, senderId, argArray)
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
  def AgentCommands.getArg(argArray, excepString)
    arg = argArray.delete_at(0)
    if (arg == nil)
      raise excepString
    end
    return arg
  end

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
  def AgentCommands.getArgDefault(argArray, default = nil)
    arg = argArray.delete_at(0)
    if (arg == nil)
      arg = default
    end
    return arg
  end

end
