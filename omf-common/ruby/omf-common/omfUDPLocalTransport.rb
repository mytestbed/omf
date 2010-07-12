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
# = omfPubSubTransport.rb
#
# == Description
#
# This file implements a generic Publish/Subscribe transport to be used by the
# various OMF entities.
#
require "omf-common/omfPubSubMessage"
require "omf-common/omfPubSubAddress"
require "socket"
require 'omf-common/mobject'

#
# This class defines a PubSub Transport
# Currently, this PubSub Transport is done over XMPP, and this class is using
# the third party library XMPP4R.
#
class OMFUDPLocalTransport < MObject 

  include Singleton
  @@started = false
  MAX_PACKET_LENGTH = 4096

  def init(opts)
    raise "UDP Local Transport already started" if @@started
    @@queue = Queue.new
    @@threads = Array.new
    @@listening = false
    @@myName = opts[:comms_name]
    @@listeningPort = opts[:config][:udplocal][:listening_port] 
    @@sendingPort = opts[:config][:udplocal][:sending_port] 
    raise "UDPLocalTransport - Configuration is missing listening/sending "+
          "ports parameter!" if !@@listeningPort || !@@sendingPort

    # Open local UPD sockets to listen and send messages 
    begin
      debug "Creating UDP sockects (recv: #{@@listeningPort} / "+
            "send: #{@@sendingPort} )"
      @@recvSock = UDPSocket.new
      @@sendSock = UDPSocket.new
      @@recvSock.bind('0.0.0.0', @@listeningPort)
    rescue Exception => ex
      raise "Failed to create UDP sockets (Error: '#{ex}')"
    end

    @@started = true
    return self
  end

  def listen(addr, &block)
    return true if @@listening 
    # When a new event comes from that server, we push it on our event queue
    # if block has been given 
    if block
      @@threads << Thread.new {
        while event = @@queue.pop
          process_queue(event, &block)
        end
      }
    end
    begin
      @@threads << Thread.new {
        event, addr = @@recvSock.recvfrom(MAX_PACKET_LENGTH)
        @@queue << event 
      }
      debug "Listening on UDP at '#{@@listeningPort}'" 
      @@listening = true
      return true
    rescue Exception => ex
      debug "Failed to listen on UDP at '#{@@listeningPort}' (Error: '#{ex}')" 
      return false
    end
  end

  def reset
    @@threads.each { |t| t.exit }
    @@queue = Queue.new
    @@threads = Array.new
  end

  def stop
    reset
    @@recvSock.close
    @@sendSock.close
  end

  def get_new_address(opts = nil)
    return OmfPubSubAddress.new(opts)
  end

  def get_new_message(opts = nil)
    return OmfPubSubMessage.new(opts)
  end

  def send(address, msg)
    message = msg.serialize.to_s
    # Sanity checks...
    if !message || (message.length == 0)
      error "send - Ignore attempt to send an empty message"
      return
    end
    begin
      @@sendSock.send(message, 0, '127.0.0.1', @@sendingPort)
    rescue Exception => ex
      error "Failed sending message to local UDP port '#{@@sendingPort}'"
      error "Failed msg: '#{message}'\nError msg: '#{ex}'"
    end
  end

  private

  def process_queue(event, &block)
    # Retrieve the command from the event
    message = event_to_message(event)
    return if !message

    # Pass the command to our communicator
    yield message
  end

  def event_to_message(event)
    begin
      # Retrieve the payload from the received message
      item = REXML::Document.new(event)
      xmlMessage = nil
      item.each_element { |e| xmlMessage = e }
      # Ignore events without a valid payload
      return nil if xmlMessage == nil
      # All good, return the extracted XML payload
      message = get_new_message
      message.create_from(xmlMessage)
      return message
    rescue Exception => ex
      error "Cannot extract message from event '#{item}'"
      error "Error: '#{ex}'"
      return
    end
  end

end
