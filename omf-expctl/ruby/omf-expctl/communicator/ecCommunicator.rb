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
# = ecCommunicator.rb
#
# == Description
#
# This file implements a Publish/Subscribe Communicator for the Node Handler.
# This PubSub communicator is based on XMPP. 
# This current implementation uses the library XMPP4R.
#
require "omf-common/omfCommunicator"
require 'omf-expctl/agentCommands'

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Node Agent (NA) aka Resource Controller will use this Communicator to 
# send/receive messages to/from the Node Handler (EC) aka Experiment Controller
# This Communicator is based on the Singleton design pattern.
#
class ECCommunicator < OmfCommunicator

  def self.init(addr, opts)
    super(opts)
    # EC-secific communicator initialisation...
    # 0 - set some attributes
    @@sliceID = addr.sliceID
    @@expID = addr.expID
    # 1 - listen to my address
    listen(addr) { |cmd| process_command(cmd) }
    # 2 - listen to the 'experiment' address
    # (i.e. same as my address but without my name)
    expAddr = create_address(addr)
    expAddr.name = nil
    listen(expAddr) { |cmd| process_command(cmd) }
  end

  #
  # This method processes the command comming from another OMF entity 
  #
  #  - argArray = command line parsed into an array
  #
  def process_command(cmdObj)
    return if !valid_command(cmdObj)
    debug "Processing '#{cmdObj.cmdType}' - '#{cmdObj.target}'"
    # Retrieve the command
    method = nil
    begin
      method = AgentCommands.method(cmdObj.cmdType.to_s)
    rescue Exception
      error "Cannot find a method to process the command '#{cmdObj.cmdType}'"
      return
    end
    # Execute the command
    begin
      reply = method.call(self, Node[cmdObj.target], cmdObj)
    rescue Exception => err
      error "While processing the command '#{cmdObj.cmdType}'"
      error "Error: #{err}"
      error "Trace: #{err.backtrace.join("\n")}" 
      return
    end
  end

  def valid_command?(cmdObj)
    # Perform some checking...
    # - Ignore commands from ourselves or another EC
    return false if OmfProtocol::ec_cmd?(cmdObj.cmdType)
    # - Ignore commands that are not known RC commands
    if !OmfProtocol::rc_cmd?(cmdObj.cmdType)
      debug "Received unknown command '#{cmdObj.cmdType}' - ignoring it!" 
      return false
    end
    # - Ignore commands for/from unknown Slice and Experiment ID
    if (cmdObj.sliceID != @@sliceID) || (cmdObj.expID != @@expID)
      debug "Received command with unknown slice and exp IDs: "+
            "'#{cmdObj.sliceID}' and '#{cmdObj.expID}' - ignoring it!" 
      return false
    end
    # - Ignore commands from unknown RCs
    if (Node[cmdObj.target] == nil)
      debug "Received command with unknown target '#{cmdObj.target}'"+
            " - ignoring it!"
      return false
    end
    return true
  end


  #
  # This method sends a reset command to a given resource
  #
  def send_reset(resourceID)
    reset_cmd = new_command(:RESET)
    reset_cmd.target = "#{resourceID}"
    send_command(reset_cmd)
  end

  #
  # This method sends a reset command to a given resource
  #
  def send_reset_all
    reset_cmd = new_command(:RESET)
    reset_cmd.target = "*"
    send_command(reset_cmd)
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

end
