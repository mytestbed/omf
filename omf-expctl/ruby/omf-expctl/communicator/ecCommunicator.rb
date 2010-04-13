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

  def self.init(opts, slice, expID)
    super()
    case type = opts[:type]
    when 'xmpp'
      require 'omf-expctl/communicator/ecPubSubTransport.rb'
      @@transport = ECPubSubTransport.init(self, opts[:xmpp], slice, expID)
    when 'mock'
      return # Uses the default Mock OmfCommunicator
    else
      raise "Unknown transport '#{type}'"
    end
  end

  #
  # This method processes the command comming from another OMF entity 
  #
  #  - argArray = command line parsed into an array
  #
  def process_command(cmdObj)
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

end
