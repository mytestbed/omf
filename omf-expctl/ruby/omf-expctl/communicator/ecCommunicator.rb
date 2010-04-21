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

  def self.init(opts)
    super(opts)
    # EC-secific communicator initialisation...
    # 0 - set some attributes
    @@sliceID = opts[:sliceID]
    @@domain = opts[:domain]
    @@expID = opts[:expID]
    # 1 - listen to my address
    # (i.e. the is the 'experiment' address)
    addr = create_address!(:sliceID => @@sliceID, 
                          :expID => @@expID, 
                          :domain => @@domain)
    listen(addr) { |cmd| process_command(cmd) }
  end

  def create_address(opts = nil)
    return create_address!(:sliceID => @@sliceID, :expID => @@expID, 
                           :domain => @@domain, :name => opts[:name])
  end

  #
  # This method processes the command comming from another OMF entity 
  #
  #  - argArray = command line parsed into an array
  #
  def process_command(cmdObj)
    return if !valid_command(cmdObj)
    debug "Processing '#{cmdObj.cmdType}' - '#{cmdObj.target}'"
    # Perform any EC-specific communicator tasks
    execute_ec_tasks(cmdObj)
    # Retrieve the method corresponding to this command
    method = nil
    begin
      method = AgentCommands.method(cmdObj.cmdType.to_s)
    rescue Exception
      error "Cannot find a method to process the command '#{cmdObj.cmdType}'"
      return
    end
    # Execute the method corresponding to this command
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

  def execute_ec_tasks(cmdObject)
    case cmdObject.cmdType
    when :ENROLLED
      # when we receive the first ENROLLED, send a NOOP message to the RC. 
      # This is necessary since if RC is reset or restarted, it might
      # receive the last ENROLL command again, depending on the kind of 
      # transport being used. In any case, sending a NOOP would prevent this.
      if !Node[cmdObject.target].isUp
        addr = create_address!(:sliceID => @@sliceID, 
                              :domain => @@domain,
                              :name => cmdObject.target)
        noop = create_command(:cmdtype => :NOOP, :target => cmdObject.target)
        send_command(addr, noop)
      end
    end
  end

  #
  # This method sends a reset command to a given resource
  #
  def send_reset(resourceID)
    addr = create_address!(:sliceID => @@sliceID, 
                           :domain => @@domain,
                           :name => "#{resourceID}")
    cmd = create_command(:cmdtype => :RESET, :target => "#{resourceID}")
    send_command(addr, cmd)
  end

  #
  # This method sends a reset command to a given resource
  #
  def send_reset_all
    send_command(create_address!(:sliceID => @@sliceID, :domain => @@domain),
                 create_command(:cmdtype => :RESET, :target => "*"))
  end

end
