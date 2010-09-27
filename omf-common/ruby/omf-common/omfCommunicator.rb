#
# Copyright (c) 2009-2010 National ICT Australia (NICTA), Australia
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
# This file defines the Communicator abstract class.
#
#

require 'omf-common/mobject'

#
# This class defines the Communicator interfaces. It is a singleton, and it 
# should be used as a base class for concrete Communicator implementations.
# Concrete implementations may use any type of underlying transport
# (e.g. TCP, XMPP, etc.)
#
class OmfCommunicator < MObject

  include Singleton
  RETRY_INTERVAL = 10
  @@started = false
  @@valid_commands = Hash.new
  @@communicator_commands = Hash.new
  @@self_commands = Array.new
  @@sent = []
  @@queue = Queue.new
  @@already_queueing = false

  def init(opts)
    raise "Communicator already started" if @@started
    @@transport = nil
    # Initiate the required Transport entity
    case type = opts[:config][:type]
    when 'xmpp'
      require 'omf-common/omfPubSubTransport'
      @@transport = OMFPubSubTransport.instance.init(opts) 
      @@domain = opts[:config][:xmpp][:pubsub_domain] || 
                 opts[:config][:xmpp][:pubsub_gateway] || nil
    when 'mock'
      @@sent = Array.new
      @@domain = 'mock_domain'
      return # Uses the default Mock OmfCommunicator
    when 'udplocal'
      require 'omf-common/omfUDPLocalTransport'
      @@transport = OMFUDPLocalTransport.instance.init(opts)
      @@domain = 'localhost'
    else
      raise "Unknown transport '#{type}'"
    end
    # Set Communicator-specific tasks, if any
    if opts[:comms_specific_tasks]
      opts[:comms_specific_tasks].each { |cmd|
        define_communicator_command(cmd) { |msg| 
          self.method(cmd.to_s).call(msg) 
        }
    }
    end
    # Start the Thread that will process message from Transport
    Thread.new {
        while message = @@queue.pop
          dispatch_message(message)
        end
    }
    @@started = true
  end

  def define_communicator_command(command_type, &block)
    @@communicator_commands[command_type] = block
  end

  def define_valid_command(command_type, &block)
    @@valid_commands[command_type] = block
  end

  def define_self_command(command_type)
    @@self_commands << command_type
  end

  def create_address(opts)
    return @@transport.get_new_address(opts) if @@transport
    addr = HashPlus.new
    opts.each { |k,v| addr[k] = v} if opts
    return addr
  end

  def create_message(opts = nil)
    return @@transport.get_new_message(opts) if @@transport
    cmd = HashPlus.new
    opts.each { |k,v| cmd[k] = v} if opts
    return cmd
  end

  def send_message(addr, message)
    if !addr
      warn "No address defined! Cannot send message '#{message}'"
      return false
    end
    if @@transport
      return @@transport.send(addr, message)
    else
      debug "Sending command '#{message}'"
      @@sent << [addr, message]
      return false
    end
  end  

  def listen(addr)
    # NOTE: if we want to allow multiple queues and threads to 
    # perform parallel processing at the Comm level, we should change the 
    # following (and already_queueing will not be needed anymore)
    if @@transport && @@already_queueing
      return @@transport.listen(addr) 
    elsif @@transport
      @@already_queueing = true
      return @@transport.listen(addr) { |message| @@queue << message } 
    end
  end

  def stop
    @@transport.stop if @@transport
  end

  def reset
    @@already_queueing = false
    @@queue.clear
    @@transport.reset if @@transport
  end

  #############################
  #############################
  
  private

  def dispatch_message(msg)
    # 1 - Retrieve and validate the message
    return if !valid_message?(msg) # Silently discard unvalid messages
    debug "Dispatch '#{msg.cmdType}' - '#{msg.target}'"
    # 2 - Perform Communicator-specific tasks, if any
    begin
      proc = @@communicator_commands[msg.cmdType]
      proc.call(msg) if not proc.nil?
    rescue Exception => ex
      error "Failed to process Communicator-specific task '#{msg.cmdType}'\n" +
            "Error: '#{ex}'\n" + "Raw message: '#{msg.to_s}'"
      return ex
    end
    # 3 - Dispatch the message to the OMF entity
    begin
      proc = @@valid_commands[msg.cmdType]
      proc.call(self, msg) if not proc.nil?
    rescue Exception => ex
      error "Failed to process the command '#{msg.cmdType}'\n" +
            "Error: #{err}\n" + "Trace: #{err.backtrace.join("\n")}" 
      return ex
    end
  end

  def valid_message?(message)
    cmd = message.cmdType
    # - Ignore commands from ourselves (or another instance of our entity)
    self_commands = @@self_commands || []
    return false if self_commands.include?(cmd)
    # - Ignore commands that are not in our list of acceptable commands
    valid_commands = @@valid_commands || []
    if !valid_commands.include?(cmd)
      debug "Ignoring unknown command '#{cmd}'"
      return false
    end
    # - Accept this message
    return true
  end

  def unimplemented_method_exception(method_name)
    "Communicator - Subclass '#{self.class}' must implement #{method_name}()"
  end
  
  def list_nodes(domain)
    @@transport.list_nodes(domain)
  end

end # END OmfCommunicator Class






#
# A simple Hash extension that allows the access to (Key,Value) using a 'dot'
# syntax. This is used by the generic OmfCommunicator class above, in case no 
# transport has been defined for it or its subclasses
#
class HashPlus < Hash
  #
  # Return or Set the values of this Hash
  # But do so via the use of method_missing, so one can query or set
  # the value of a key using a 'dot' syntax.
  # E.g. For myHash[myKey] = 123, we can use: myHash.myKey = 123 
  # E.g. For var = myHash[myKey], we can use: var = myHash.myKey
  # Also notes that keys in this hash are all Symbols in capital letters
  #
  # - key = the key to act on
  #
  # [Return] the value of the key, if called as a query
  #
  def method_missing(key, *args, &blocks)
    method = key.to_s.upcase
    if method[-1,1] == "="
      k = method[0..-2]
      self[k.to_sym] = args[0]
    else
      return self[key.to_s.upcase.to_sym]
    end
  end
end # END HashPlus Class
