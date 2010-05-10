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
#
require "omf-common/omfCommunicator"
require "omf-common/omfProtocol"
require 'omf-resctl/omf_agent/agentCommands'

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Node Agent (NA) aka Resource Controller will use this Communicator to 
# send/receive messages to/from the Node Handler (EC) aka Experiment Controller
# This Communicator is based on the Singleton design pattern.
#

class RCCommunicator < OmfCommunicator

  def init(opts)
    super(opts)
    # EC-secific communicator initialisation...
    # 0 - set some attributes
    @@myName = opts[:comms_name]
    @@sliceID = opts[:sliceID]
    @@expID = nil
    @@myAliases = [@@myName, "*"]
    # 1 - Build my address for this slice 
    @@myAddr = create_address(:sliceID => @@sliceID, 
                              :name => @@myName, 
                              :domain => @@domain)
    # 3 - Set my lists of valid commands 
    OmfProtocol::EC_COMMANDS.each { |cmd|
      define_valid_command(cmd) { |handler, comm, message| 
        AgentCommands.method(cmd.to_s).call(handler, comm, message) 
      }	
    }
    # 4 - Set my list of own/self commands
    OmfProtocol::RC_COMMANDS.each { |cmd| define_self_command(cmd) }
  end

  def listen_to_group(group)
    addr = create_address(:sliceID => @@sliceID, :expID => @@expID, 
                          :domain => @@domain, :name => group)
    add_alias(group)
    return listen(addr)
  end

  def listen_to_experiment(expID)
    addr = create_address(:sliceID => @@sliceID, :expID => expID, 
                          :domain => @@domain)
    success = listen(addr)
    @@expID = expID if success    
    return success
  end

  def set_EC_address(ec_address = nil)
    myEC = ec_address ? ec_address : @@myName
    @@myECAddress = create_address(:sliceID => @@sliceID, :expID => @@expID, 
                        :domain => @@domain, :name => myEC)
  end

  #
  # Send an ENROLLED reply to the EC. 
  # This is done when a ENROLL or ALIAS command has been successfully 
  # processed.
  #
  # - aliases = a String with the names of all the groups within which we have 
  #             enrolled
  #
  #def send_enrolled_reply(aliases = nil)
  #  reply = create_message(:cmdtype => :ENROLLED, :target => @@myName)
  #  reply.name = aliases if aliases != nil
  #  send_message(@@myECAddress, reply)
  #end

  #
  # Send an WRONG_IMAGE reply to the EC. 
  # This is done when the current disk image of this RC is not the disk
  # image requested by the EC.
  #
  #def send_wrong_image_reply
  #  reply = create_message(:cmdtype => :WRONG_IMAGE, :target => @@myName, 
  #                         :image => imageName) 
  #  # 'WRONG_IMAGE' message goes even if we are not part of an Experiment yet!
  #  # Thus we create directly the address 
  #  addr = create_address(:name => @@myName, :sliceID => @@sliceID,
  #                        :domain => @@domain)
  #  send_message(addr, reply)
  #end

  #
  # Send an OK reply to the EC. 
  # This is done for some received EC commands that were executed successfully
  # (e.g. a successful CONFIGURE executing)
  #
  # - info = a String with more info on the command execution
  # - command = the command that executed successfully
  #
  #def send_ok_reply(info, command)
  #  reply = create_message(:cmdtype => :OK, :target => @@myName, 
  #                         :message => info, :cmd => command.cmdType.to_s) 
  #  reply.path = command.path if command.path != nil
  #  reply.value = command.value if command.value != nil
  #  send_message(@@myECAddress, reply)
  #end

  #
  # Send an ERROR reply to the EC. 
  # This is done when an error occured while executing a received EC command
  # (e.g. a problem when executing a CONFIGURE command)
  #
  # - info = a String with more info on the command execution
  # - command = the command that failed to execute 
  #
  #def send_error_reply(info, command)
  #  reply = create_message(:cmdtype => :ERROR, :target => @@myName, 
  #                         :cmd => command.cmdType.to_s, :message => info) 
  #  reply.path = command.path if command.path != nil
  #  reply.appID = command.appID if command.appID != nil
  #  reply.value = command.value if command.value != nil
  #  send_message(@@myECAddress, reply)
  #end

  def send_reply(type, reason, info, original_request)
    reply = create_message(:cmdtype => type, :target => @@myName, 
                           :cmd => reason ,:message => info) 
    reply.path = original_request.path if original_request.path != nil
    reply.appID = original_request.appID if original_request.appID != nil
    reply.value = original_request.value if original_request.value != nil
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
    @@expID = nil
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
    # Also listen to the generic resource address for this slice
    listening = false
    addr = create_address(:sliceID => @@sliceID, :domain => @@domain) 
    while !listening
      listening = listen(addr)
      if !listening
        debug "Cannot listen on address: '#{@@myAddr}' - retry in "+
              "#{RETRY_INTERVAL} sec."
        sleep RETRY_INTERVAL
      end
    end
  end

  private

  def send_message(addr, message)
    message.sliceID = @@sliceID
    message.expID = @@expID
    super(addr, message)
  end

  def dispatch_message(message)
    result = super(message)
    if result && result.kind_of(Hash)
      send_reply(result[:success], result[:reason], result[:info], message)
      #send_error_reply("Failed to process command (Error: '#{result}')", 
      #                 message) 
    end
  end
  
  def valid_message?(message)
    # 1 - Perform common validations amoung OMF entities
    return false if !super(message) 
    # 2 - Perform RC-specific validations
    # - Ignore messages for/from unknown Slice and Experiment ID
    if (message.cmdType != :ENROLL) && (message.cmdType != :RESET) &&
       ((message.sliceID != @@sliceID) || (message.expID != @@expID))
      debug "Ignoring message with unknown slice "+
            "and exp IDs: '#{message.sliceID}' and '#{message.expID}'" 
      return false
    end
    # - Ignore commands that are not address to us 
    # (There may be multiple space-separated targets)
    dst = message.target.split(' ') 
    forMe = false
    dst.each { |t| forMe = true if @@myAliases.include?(t) }
     if !forMe
       debug "Ignoring command with unknown target "+
             "'#{message.target}' - ignoring it!"
       return false
    end
    # Accept this message
    return true
  end

  def add_alias(newAlias)
    if (@@myAliases.index(newAlias) != nil)
      debug("Alias '#{newAlias}' already registered.")
    else
      @@myAliases.insert(0, newAlias)
    end
    debug("Agent names #{@@myAliases.join(', ')}")
  end

end
