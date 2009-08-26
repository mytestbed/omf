#
# Copyright (c) 2009 National ICT Australia (NICTA), Australia
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
# This file abstracts the communicator used 

# IMPORTANT 
# This require has to be done here!
# This is because xmpp4r uses ruby's default 'logger' while mobject uses 'log4r'
# When the order is not right, logging would broke, and other things with it
# Really know what you are doing if you want to change this!
require 'omf-expctl/xmppCommunicator.rb'

class Communicator 
  
  def self.instance()
    @@instance
  end
  
  def self.init(opts)
    raise "Communicator already started" if @@instance

    case type = opts['type']
    when 'xmpp'
      @@instance = XmppCommunicator.init(opts['xmpp'])
    when 'mock'
      @@instance = MockCommunicator.new()
    else
      raise "Unknown communicator '#{type}'"
    end
  end
  
  def getAppCmd()
    @appCmdStruct ||= Struct.new(:group, :procID, :env, :path, :cmdLine, :omlConfig)
    @appCmdStruct.new
  end
  
  def sendAppCmd(cmd)
    raise "Not implemented by '#{self.class}'"
  end
  
  #
  # For testing only
  #
  def self.reset()
    @@instance = nil
  end

  @@instance = nil
end

class MockCommunicator < Communicator
  require 'pp'
  
  attr_reader :cmds

  def initialize()
    super('mockCommunicator')
    @cmds = []
  end
  
  def send(ns, command, args)
    @cmds << "#{ns}|#{command}|#{args.join('#')}"
  end
  
  def sendAppCmd(cmd)
    pp cmd
  end

end

