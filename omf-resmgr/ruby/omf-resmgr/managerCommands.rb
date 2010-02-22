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
# This module contains all the commands understood by an agent
# Any change to the sematics of the commands, or the addition
# of new ones should be reflected in a change of the
# PROTOCOL_VERSION.
#

require 'omf-common/mobject'
require 'omf-common/execApp'

module AgentCommands

  OMF_MM_VERSION = OMF::Common::MM_VERSION()

  #
  # Command 'CREATE_SLIVER'
  #
  # Create a Sliver on this resource for a given Slice 
  #
  # - agent = the instance of this RM
  # - cmdObject = a Command Object holding all the information required to 
  #               create a sliver on this resource 
  #
  def AgentCommands.CREATE_SLIVER(agent, cmdObject)
    sliceName = cmdObject.slicename
    resourceName = cmdObject.resname
    sliverType = cmdObject.slivertype
    commAddress = cmdObject.commaddr
    commUser = cmdObject.commuser
    commPassword = cmdObject.commpwd
    # Create the sliver ...
    #success = false
    success = true
    #....

    # Reply to the command
    if success  
      msg = "Created Sliver for slice '#{sliceName}' on '#{resourceName}'"
      agent.okReply(msg, cmdObject)
    else
      msg = "Failed creating Sliver for slice '#{sliceName}' on '#{resourceName}'"
      agent.errorReply(msg, cmdObject)
    end
    MObject.debug(msg)
  end

  #
  # Command 'DELETE_SLIVER'
  #
  # Delete a Sliver on this resource for a given Slice 
  #
  # - agent = the instance of this RM
  # - cmdObject = a Command Object holding all the information required to 
  #               delete a sliver on this resource 
  #
  def AgentCommands.DELETE_SLIVER(agent, cmdObject)
    sliceName = cmdObject.slicename
    resourceName = cmdObject.resname
    # delete the sliver ...
    #success = false
    success = true
    #....

    # Reply to the command
    if success  
      msg = "Deleted Sliver for '#{sliceName}' on '#{resourceName}'"
      agent.okReply(msg, cmdObject)
    else
      msg = "Failed deleteing Sliver for '#{sliceName}' on '#{resourceName}'"
      agent.errorReply(msg, cmdObject)
    end
    MObject.debug(msg)
  end

  #
  # Command 'EXECUTE'
  #
  # Execute a program on the machine running this NA
  #
  # - agent = the instance of this NA
  # - cmdObject = a Command Object holding all the information required to 
  #               execute this command 
  #
  def AgentCommands.EXECUTE(agent, cmdObject)
    id = cmdObject.appID

    # Dump the XML description of the OML configuration into a file, if any
    if (xmlDoc = cmdObject.omlConfig) != nil
      configPath = nil
      xmlDoc.each_element("omlc") { |omlc|
        configPath = "/tmp/#{omlc.attributes['exp_id']}-#{id}.xml"
      }
      f = File.new(configPath, "w+")
      xmlDoc.each_element {|el|
        f << el.to_s
      }
      f.close
    end

    # Set the full command line and execute it
    fullCmdLine = "env -i #{cmdObject.env} OML_CONFIG=#{configPath} #{cmdObject.path} #{cmdObject.cmdLineArgs}"
    MObject.debug "Executing: '#{fullCmdLine}'"
    ExecApp.new(id, agent, fullCmdLine)
  end

  #
  # Command 'KILL'
  #
  # Send a signal to a process running on this node
  #
  # - agent = the instance of this NA
  # - cmdObject = a Command Object holding all the information required to 
  #               execute this command
  #
  def AgentCommands.KILL(agent, cmdObject)
    id = cmdObject.appID
    signal = cmdObject.value
    ExecApp[id].kill(signal)
  end

  #
  # Command 'EXIT'
  #
  # Terminate an application running on this node
  # First try to send the message 'exit' on the app's STDIN
  # If no succes, then send a Kill signal to the process
  #
  # - agent = the instance of this NA
  # - cmdObject = a Command Object holding all the information required to 
  #               execute this command
  #
  def AgentCommands.EXIT(agent, cmdObject)
    id = cmdObject.appID
    begin
      # First try sending 'exit' on the app's STDIN
      MObject.debug("Sending 'exit' message to STDIN of application: #{id}")
      ExecApp[id].stdin('exit')
      # If apps still exists after 4sec...
      sleep 4
      if ExecApp[id] != nil
        MObject.debug("Sending 'kill' signal to application: #{id}")
        ExecApp[id].kill('KILL')
      end
    rescue Exception => err
      raise Exception.new("- Error while terminating application '#{id}' - #{err}")
    end
  end

  #
  # Command 'RESET'
  #
  # Reset this node agent
  #
  # - agent = the instance of this NA
  # - cmdObject = a Command Object holding all the information required to 
  #               execute this command
  #
  def AgentCommands.RESET(agent, cmdObject)
    agent.reset
  end

end
