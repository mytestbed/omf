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
# = rcCommunicator.rb
#
# == Description
#
# This file implements a Publish/Subscribe Communicator for the Node Agent.
# This PubSub communicator is based on XMPP. 
# This current implementation uses the library XMPP4R.
#
# NOTE: Extensive modification by TR from the original code from Javid
# TODO: Remove or Comment debug messages marked as 'TDEBUG'
#
require "omf-common/omfCommunicator"
require 'omf-resctl/omf_agent/agentCommands'

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Node Agent (NA) aka Resource Controller will use this Communicator to 
# send/receive messages to/from the Node Handler (EC) aka Experiment Controller
# This Communicator is based on the Singleton design pattern.
#

class RCCommunicator < OmfCommunicator

  def self.init(opts)
    opts[:comms_specific_tasks] = [:ENROLL, :ALIAS]
    super(opts)
    # RC-secific communicator initialisation...
    # 0 - set some attributes
    @@myName = opts[:comms_name]
    @@sliceID = opts[:sliceID]
    @@domain = opts[:domain]
    @@expID = nil
    # 1 - Build my address for this slice 
    @@myAddr = create_address!(:sliceID => @@sliceID, 
                              :name => @@myName, 
                              :domain => @@domain)
    # 3 - Set my lists of valid and specific commands
    OmfProtocol::EC_COMMANDS.each { |cmd|
      defValidCommand(cmd) { |h, m| AgentCommands.method(cmd.to_s).call(h, m) }	
    }
  end

  def create_address(opts = nil)
    if !@@expID
      error "Not enrolled in an experiment yet, thus cannot create an address!"
      return
    end
    return create_address!(:sliceID => @@sliceID, :expID => @@expID, 
                           :domain => @@domain, :name => opts[:name])
  end

  def reset
    super()
    @@expID = nil
    # Listen to my address - wait and try again until successfull
    listening = false
    while !listening
      listening = listen(@@myAddr) { |cmd| dispatch_message(cmd) }
      debug "Cannot listen on '#{@@myAddr.to_s}' - "+
            "retrying in #{RETRY_INTERVAL} sec."
      sleep RETRY_INTERVAL
    end
    # Also listen to the generic resource address for this slice
    listening = false
    addr = create_address(:sliceID => @@sliceID, :domain => @@domain)) 
    while !listening
      listening = listen(addr)
      debug "Cannot listen on '#{addr.to_s}' - "+
            "retrying in #{RETRY_INTERVAL} sec."
      sleep RETRY_INTERVAL
    end
  end

  private

  def dispatch_message(message)
    error_msg = super(message)
    if result
       send_error_reply("Failed to process command (Error: '#{error_msg}')", 
                        eval(@@messageType).create_from(message)) 
    end
  end

  def valid_message?(message)
    # 1 - Perform common validations amoung OMF entities
    return false if !super(message) 
    # 2 - Perform RC-specific validations
    # - Ignore messages for/from unknown Slice and Experiment ID
    if (message.cmdType != :ENROLL) &&
       ((message.sliceID != @@sliceID) || (message.expID != @@expID))
      debug "Received message with unknown slice and exp IDs: "+
            "'#{message.sliceID}' and '#{message.expID}' - ignoring it!" 
    return false
    # - Ignore commands that are not address to us 
    # (There may be multiple space-separated targets)
    dst = message.target.split(' ') 
    forMe = false
    dst.each { |t| forMe = true if NodeAgent.instance.agentAliases.include?(t) }
     if !forMe
       debug "Received command with unknown target '#{message.target}'"+
             " - ignoring it!" 
       return false
    end
    # Accept this message
    return true
  end

  def ENROLL(cmd)
    # Set our expID and listen to our addresses for this experiment
    if !NodeAgent.instance.enrolled
      @@expID = cmdObject.expID
      debug "Experiment ID: '#{@@expID}'"
      addrNode = create_address(:name => cmdObject.target)
      addrExp = create_address()
      if !listen(addrNode) || !listen(addrExp)
        error "Failed to Process ENROLL command!"
        error "Maybe this is an ENROLL from an old experiment - ignoring it!"
        return
      end
    else
      debug "Received ENROLL, but I am already ENROLLED! - ignoring it!"
      return
    end
  end

  def ALIAS(cmd)
    addrAlias = create_address(:name => cmdObject.name)
    listen(addrAlias)
  end

end
