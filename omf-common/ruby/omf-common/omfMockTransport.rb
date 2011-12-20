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
# = omfMockTransport.rb
#
# == Description
#
# This file implements a transport for testing.
#
require "omf-common/communicator/omfPubSubMessage"
require "omf-common/communicator/omfPubSubAddress"
require 'omf-common/mobject'

#
# This class defines a mock transport for testing.
#
class OMFMockTransport < MObject 

  def init(opts)
    #puts "MOCK: #{opts.inspect}"
    @mopts = opts[:config][:mock] || {}
    puts "MOCK: #{@mopts.inspect}"
    return self
  end

  def listen(addr, &block)
    return true 
  end

  def reset
  end

  def stop
  end

  def get_new_address(opts = nil)
    return OmfPubSubAddress.new(opts)
    # addr = HashPlus.new
    # opts.each { |k,v| addr[k] = v} if opts
    # return addr
    
  end

  def get_new_message(opts = nil)
    return OmfPubSubMessage.new(opts)
    
    # cmd = HashPlus.new
    # opts.each { |k,v| cmd[k] = v} if opts
    # return cmd
    
  end

  def send(address, msg)
    puts "SENDING: #{msg.inspect}"
    return true
  end
  
  def list_nodes(domain)
    puts "LIST: #{@mopts[:resources].inspect}"
    @mopts[:resources] || []
  end


end
