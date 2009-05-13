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
# = communicator.rb
#
# == Description
#
# This class provides a communication layer between
# the handler and all agents.
#

require 'omf-expctl/agentCommands'
require 'omf-common/execApp'
require 'singleton'
require 'omf-common/lineSerializer'

#
# This class provides a communication layer between
# the handler and all agents.
# Only one Communicator instance can be created during the 
# execution of the NodeHandler (Singleton pattern)
#
class Communicator < MObject
  
  include Singleton
  @@instantiated = false

  #
  # Return true if a Communicator instance has already been created
  #
  # [Return] true/false
  #
  def Communicator.instantiated?
    return @@instantiated
  end

  private_class_method :new

  #
  # Create a new Communicator instance
  #
  def initialize()
    @name2node = Hash.new
    if NodeHandler.JUST_PRINT
      puts ">> Opening communication channels"
    else
      @handlerCommands = Hash.new
      serverCmd = OConfig['commServer'] || raise("OConfig: Missing 'commServer' path" )
      serverCmd = serverCmd.gsub(/%ID%/, Experiment.ID)
      @server = ExecApp.new(:commServer, self, serverCmd)
      sleep 2 # give the app time to start or fail
    end
    @@instantiated = true
  end

  #
  # This method sends a message to one or multiple nodes
  # Format: <sequenceNo target command arg1 arg2 ...>
  #
  # - target =  a String with the name of the group of node(s) that should process this message
  # - command = the NodeAgent command that should be executed
  # - msgArray = an Array with the arguments for this NodeAgent command
  #
  def send(target, command, msgArray = [])
    msg = "S #{target} #{command} #{LineSerializer.to_s(msgArray)}"
    debug("Send message: ", msg)
    write(msg)
   end

  #
  # This method sends a message unreliably. 
  # This means sending a message with a sequence number of 0.
  # Format: <0 target command arg1 arg2 ...>
  #
  # - target =  a String with the name of the group of node(s) that should process this message
  # - command = the NodeAgent command that should be executed
  # - msgArray = an Array with the arguments for this NodeAgent command
  #
  def sendUnreliably(target, command, msgArray = [])
    msg = "s #{target} #{command} #{LineSerializer.to_s(msgArray)}"
    debug("Send unreliable message: ", msg)
    write(msg)
  end

  #
  # This method sends a reset message to all connected nodes
  #
  def sendReset()
    write("R")
  end

  #
  # This method enrolls 'node' with 'ipAddress' and 'name'
  # When this node checks in, it will automatically
  # get 'name' assigned.
  #
  # - node =  id of the node to enroll
  # - name = name to give to the node once enrolled
  # - ipAddress = IP address of the node to enroll 
  #
  def enrollNode(node, name, ipAddress)
    @name2node[name] = node
    write("a #{ipAddress} #{name}")
  end

  #
  # This method removes a node from the Communicator's list of 'alive' nodes.
  # When a given 'Node' object is being removed from all the existing 
  # topologies, it calls this method to notify the Communicator, so 
  # subsequent messages received from the real physical node will be 
  # discarded by the Commnunicator in the processCommand() call.
  # Furthermore, 'X' command is sent to the commServer to remove all
  # group associated to this node at the commServer level. Finally, a
  # 'RESET' command is sent to the real node.
  #
  # - name = name of the node to remove
  #
  def removeNode(name)
    @name2node[name] = nil
    write("X #{name}")
    write("s #{name} RESET")
  end

  #
  # This method adds a node to an existing/new group
  # (a node can belong to multiple group)
  #
  # - nodeName = name of the node 
  # - groupName =  name of the group to add the node to
  #
  def addToGroup(nodeName, groupName)
    write("A #{nodeName} #{groupName}")
  end

  #
  # This methods sends a 'quit' message to all the nodes
  #
  def quit()
    begin
      write('q')
      sleep 2
    rescue
      #ignore
    end
  end

  #
  # Process an Event coming from an application running on 
  # one of the nodes.
  # (this method is called by ExecApp which is monitoring
  # the 'commServer' process.) 
  #
  # - eventName = name of the received Event
  # - appId = Id of the monitored application 
  # - msg = Optional message
  #
  def onAppEvent(eventName, appId, msg = nil)
    eventName = eventName.to_s.upcase
    if (msg != nil && eventName == "STDOUT" && msg[0] == ?#)
      ma = msg.slice(1..-1).strip.split
      cmd = ma.shift
      msg = ma.join(' ')
      if cmd == 'WARN'
        MObject.warn('commServer', msg)
      elsif cmd == 'ERROR'
        MObject.error('commServer', msg)
      else
        MObject.debug('commServer', msg)
      end
      return
    end

    debug("commServer(#{eventName}): '#{msg}'")
    if (eventName == "STDOUT")
      a = LineSerializer.to_a(msg)
      processCommand(a)
    elsif (eventName == "DONE.ERROR")
      error("ComServer failed: ", msg)
      @server = nil
    end
  end

  private

  #
  # This method processes the command comming from an agent
  #
  #  - argArray = command line parsed into an array
  #
  def processCommand(argArray)
    debug "Process message '#{argArray.join(' ')}'"
    if argArray.size < 2
      raise "Command is too short '#{argArray.join(' ')}'"
    end
    senderId = argArray.delete_at(0)
    sender = @name2node[senderId]

    if (sender == nil)
      debug "Received message from unknown sender '#{senderId}': '#{argArray.join(' ')}'"
      return
    end
    command = argArray.delete_at(0)
    # First lookup this comand within the list of handler's Commands
    method = @handlerCommands[command]
    # Then, if it's not a handler's command, lookup it up in the list of agent's commands
    if (method == nil)
      begin
        method = @handlerCommands[command] = AgentCommands.method(command)
      rescue Exception
        warn "Unknown command '#{command}' received from '#{senderId}'"
        return
      end
    end
    begin
      # Execute the command
      reply = method.call(self, sender, senderId, argArray)
    rescue Exception => ex
      #error("Error ('#{ex}') - While processing agent command '#{argArray.join(' ')}'")
      debug("Error ('#{ex}') - While processing agent command '#{argArray.join(' ')}'")
    end
  end

  #
  # This method writes a message to the commServer
  #
  # - msg =  message to write (String)
  #
  def write(msg)
    if NodeHandler.JUST_PRINT
      puts ">> MSG: #{msg}"
    else
      if @server
        @server.stdin(msg)
      else
        error("Dropped message to node: ", msg)
      end
    end
  end

end
