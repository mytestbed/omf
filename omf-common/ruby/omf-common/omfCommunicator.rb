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

  @@instance = nil
  @@cmds = []

  def self.instance
    @@instance
  end

  def self.init
    raise "Communicator already started" if @@instance
    @@instance = self.new
    @@transport = nil
  end

  #
  # Return a Command Object which will hold all the information required to send
  # a command to another OMF entity.
  # If a Transport entity has been defined for this Communicator, then the 
  # the returned Object is the one defined by the Transport entity. 
  # If not, then the returned Object is a default Hash.
  # Subclasses of communicators may define their own type of Command Object.
  # The returned Command Object should have at least the following attribut
  # and corresponding accessors: :CMDTYPE = type of the command
  #
  # - type = the type of this Command Object
  #
  # [Return] an Object with the information on a command between OMF entities 
  #
  def new_command(type)
    if @@transport
      return  @@transport.new_command(type)
    else
      #cmd = Hash.new
      cmd = HashPlus.new
      cmd[:CMDTYPE] = type
      return cmd
    end
  end

  def send_command(cmdObject)
    if @@transport
      @@transport.send_commamd(cmdObject)
    else
      debug "Sending command '#{cmdObject}'"
      @@cmds << cmdObject
  end

  def stop
    if @@transport
      @@transport.stop
    end
  end

  def start
    raise unimplemented_method_exception("start")
  end

  def process_command(command)
    raise unimplemented_method_exception("process_command")
  end


  def unimplemented_method_exception(method_name)
    "Communicator - Subclass '#{self.class}' must implement #{method_name}()"
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
