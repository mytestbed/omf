#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
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
# = RMCommunicator.rb
#
# == Description
#
# This file implements a Publish/Subscribe Communicator for the Resource Manager.
# This PubSub communicator is based on XMPP. 
# This current implementation uses the library XMPP4R.
#
#
require "omf-common/communicator/omfCommunicator"
require "omf-common/communicator/omfProtocol"
require "omf-resmgr/managerCommands"

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# This Communicator is based on the Singleton design pattern.
#

class RMCommunicator < OmfCommunicator

  def init(opts)
    super(opts)
    # EC-secific communicator initialisation...
    # 0 - set some attributes
    @@myName = opts[:comms_name]
    # 1 - Build my address for this slice 
    @@myAddr = create_address(:name => @@myName, 
                              :domain => @@domain)
    # 3 - Set my lists of valid commands 
    OmfProtocol::SLICEMGR_COMMANDS.each { |cmd|
      define_valid_command(cmd) { |handler, comm, message|
        ManagerCommands.method(cmd.to_s).call(handler, comm, message)
      }
    }
    # 4 - Set my list of own/self commands
    OmfProtocol::RM_COMMANDS.each { |cmd| define_self_command(cmd) }
  end

  def send_reply(type, reason, info, original_request)
    reply = create_message(:cmdtype => type, :target => @@myName, 
                           :cmd => reason ,:message => info) 
    reply.merge(original_request)
    send_message(@@myECAddress, reply)
  end

  #
  # Send a APP or DEV EVENT message to the EC. 
  # This is done when an application started on this resource or a device
  # configured on this resource has a new event to share with the EC
  # (e.g. a message coming on standard-out of the appliation)
  # (e.g. a change of configuration for the device)
  #
  # - type = type of the event (:APP_EVENT or :DEV_EVENT)
  # - name = the name of event
  # - id = the id of the application/device issuing this event
  # - info = a String with the new event info
  #
  def send_event(type, name, id, info)
    message = create_message(:cmdtype => type, :target => @@myName, 
                             :value => name, :appID => id, :message => info) 
    send_message(@@myECAddress, message)
  end

  def reset
    super()
    @@myAliases = [@@myName, "*"]
    # Listen to my address - wait and try again until successfull
    listening = false
    while !listening
      listening = listen(@@myAddr) 
      if !listening
        debug "Cannot listen on address: '#{@@myAddr}' - retry in "+
              "#{RETRY_INTERVAL} sec."
        sleep RETRY_INTERVAL
      end
    end
  end

  private

  def send_message(addr, message)
    super(addr, message)
  end

  def dispatch_message(message)
    result = super(message)
    if result && result.kind_of?(Hash)
      send_reply(result[:success], result[:reason], result[:info], message)
      #send_error_reply("Failed to process command (Error: '#{result}')", 
      #                 message) 
    end
  end
  
  def valid_message?(message)
    # 1 - Perform common validations among OMF entities
    return false if !super(message) 
    # 2 - Perform RM-specific validations
    # - Ignore commands that are not address to us 
    # (There may be multiple space-separated targets)
    # forMe = false
    # 
    # dst.each { |t| debug t }
    # dst.each { |t| forMe = true if @@myName == t }
    # if !forMe
    #    debug "Ignoring command with unknown target "+
    #          "'#{message.target}' - ignoring it!"
    #    return false
    # end
    # Accept this message
    return true
  end

end
