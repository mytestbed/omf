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
require "omf-common/omfProtocol"
require 'omf-expctl/agentCommands'

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Node Agent (NA) aka Resource Controller will use this Communicator to 
# send/receive messages to/from the Node Handler (EC) aka Experiment Controller
# This Communicator is based on the Singleton design pattern.
#
class ECCommunicator < OmfCommunicator

  def init(opts)
    super(opts)
    # EC-secific communicator initialisation...
    # 0 - set some attributes
    @@sliceID = opts[:sliceID]
    @@expID = opts[:expID]
    # 1 - listen to my address (i.e. the is the 'experiment' address)
    addr = create_address(:sliceID => @@sliceID, 
                          :expID => @@expID, 
                          :domain => @@domain)
    listen(addr) 
    # 3 - Set my lists of valid and specific commands
    OmfProtocol::RC_COMMANDS.each { |cmd|
      define_valid_command(cmd) { |handler, comm, message| 
        AgentCommands.method(cmd.to_s).call(handler, comm, message) 
      }	
    }
    # 4 - Set my list of own/self commands
    OmfProtocol::EC_COMMANDS.each { |cmd| define_self_command(cmd) }
  end

  #
  # Send a NOOP command to a given resource
  #
  def send_noop(resID)
    addr = create_address(:sliceID => @@sliceID, 
                           :domain => @@domain,
                           :name => "#{resID}")
    cmd = create_message(:cmdtype => :NOOP, :target => "#{resID}")
    send_message(addr, cmd)
  end

  #
  # Send a RESET command to a given resource
  #
  def send_reset(resID)
    addr = create_address(:sliceID => @@sliceID, 
                           :domain => @@domain,
                           :name => "#{resID}")
    cmd = create_message(:cmdtype => :RESET, :target => "#{resID}", 
                         :sliceID => @@sliceID, :expID => @@expID)
    send_message(addr, cmd)
  end

  #
  # Sends a reset command to a given resource
  #
  def send_reset_all
    send_message(create_address(:sliceID => @@sliceID, :domain => @@domain),
                 create_message(:cmdtype => :RESET, :target => "*"))
  end

  def make_address(opts = nil)
    return create_address(:sliceID => @@sliceID, :expID => @@expID, 
                           :domain => @@domain, :name => opts[:name])
  end

  private

  def valid_message?(message)
    # 1 - Perform common validations amoung OMF entities
    return false if !super(message)
    # 2 - Perform EC-specific validations
    # - Ignore messages for/from unknown Slice and Experiment ID
    if (message.sliceID != @@sliceID) || (message.expID != @@expID)
      MObject.debug("ECCommunicator", "Ignoring message with unknown slice "+
                    "and exp IDs: '#{message.sliceID}' and '#{message.expID}'")
      return false
    end
    # - Ignore message from unknown RCs
    if (Node[message.target] == nil)
      MObject.debug("ECCommunicator", "Ignoring command with unknown target "+
                    "'#{message.target}'")
      return false
    end
    # Accept this message
    return true
  end

end
