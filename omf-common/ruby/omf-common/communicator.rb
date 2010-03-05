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
# This class defines the Communicator interfaces.  This class should
# be used as a base class for concrete Communicator implementations.
# Concrete implementations may use any type of underlying transport
# (e.g. TCP, XMPP, etc.)
#
class Communicator < MObject

  #
  # Return an Object which will hold all the information required to send
  # a command to the resources.
  # By default this Object is a structure. However, different type of
  # communicators (i.e. sub-classes of this class) can define their own type
  # for the Command Object.
  #
  # The returned Command Object should have the following public accessors:
  # - type = type of the command
  # - group = name of the group to which this command is addressed
  # - procID = name of this command (optional)
  # - env = a Hash with the optional environment to set for this command (optional)
  # - path = the full path to the application for this command
  # - cmdLineArgs = an Array with the full command line arguments to append to this command (optional)
  # - omlConfig =  an XML configuration element for OML (optional)
  #
  # [Return] an Object holding all the information to execute an application
  #
  def new_command()
    @cmdStruct ||= Struct.new(:type, :group, :procID, :env, :path, :cmdLineArgs, :omlConfig)
    cmd = @cmdStruct.new()
    cmd.env = {}
    cmd
  end

  def start
    raise unimplemented_method_exception("start")
  end

  def stop
    raise unimplemented_method_exception("stop")
  end

  def process_event(event)
    raise unimplemented_method_exception("process_event")
  end

  def process_command(command)
    raise unimplemented_method_exception("process_command")
  end

  def send!(message, destination)
    raise unimplemented_method_exception("send!")
  end

  def unimplemented_method_exception(method_name)
    "Communicator subclass '#{self.class}' must implement #{method_name}()"
  end
end

class MockCommunicator < Communicator
  require 'pp'

  attr_reader :cmds, :cmdActions

  def initialize()
    super('mockCommunicator')
    @cmds = []
    @cmdActions = []
  end

  def send(ns, command, args)
    @cmds << "#{ns}|#{command}|#{args.join('#')}"
  end

  def sendAppCmd(cmd)
    @cmdActions << cmd
#    pp cmd
  end

end

