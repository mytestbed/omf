#
# Copyright (c) 2010 National ICT Australia (NICTA), Australia
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
# = xmppCommunicator.rb
#
# == Description
#
# This file implements a Publish/Subscribe Communicator.
# This PubSub communicator is based on XMPP.
# This current implementation uses the library XMPP4R.
#
# Each entity that wants to do PubSub with XMPP should use this
# communicator, or sub-class it if it needs to.
#

require "omf-common/omfPubSubService"
require "omf-common/omfCommandObject"
require 'omf-common/communicator'
require 'omf-common/mobject'

#
# This class defines a Communicator entity using the XMPP
# Publish/Subscribe transport embodied in OmfPubSubService.  This
# Communicator is based on the Singleton design pattern.
#
class XmppCommunicator < Communicator
  include Singleton

  PING_INTERVAL = 3600
  RETRY_INTERVAL = 10

  @@valid_commands = nil
  @@communicator_actions = nil
  @@command_actions = nil

  def self.init(opts)
    debug("Initializing a new XmppCommunicator (or subclass)")
    @@server = opts[:server]
    @@user = opts[:user]
    @@password = opts[:password] || "123"
    raise "#{self.class}: Missing ':server' option in configuration" unless @@server
    raise "#{self.class}: Missing ':user' option in configuration" unless @@user
  end

  #
  # Create a new Communicator
  #
  def initialize()
    raise "#{self.class}: Missing ':server' option in configuration" unless @@server
    raise "#{self.class}: Missing ':user' option in configuration" unless @@user

    super('xmppCommunicator')
    @service = nil
    @queue = Queue.new
    Thread.new {
      while event = @queue.pop
        execute_command(event)
      end
    }
  end

  def new_command(cmdType)
    return OmfCommandObject.new(cmdType)
  end


  #
  # Configure and start the Communicator.
  # This method instantiates a PubSub Service Helper, which will connect to the
  # PubSub server, and handle all the communication from/towards this server.
  # This method also sets the callback method, which will be called upon incoming
  # messages.
  #
  def start
    debug "Connecting to PubSub Server: '#{@@server}'"

    # Check that the PubSub server is reachable. (Otherwise suffer a
    # long hang with no feedback to the user.)
    check = false
    while !check
      cmd = "ping -c 1 #{@@server}"
      reply = `ping -c 1 #{@@server}`
      if $?.success?
        check = true
      else
        info "Could not resolve or contact: '#{@@server}' - Waiting #{RETRY_INTERVAL} sec before retrying..."
        sleep RETRY_INTERVAL
      end
    end

    debug "PubSub Server '#{@@server}' contacted, establishing connection"
    # Create a Service Helper to interact with the PubSub Server
    begin
      @service = OmfPubSubService.new(@@user, @@password, @@server)
      # Start our Event Callback, which will process Events from the
      # nodes we subscribe to.
      @service.add_event_callback do |event|
        @queue << event
      end
    rescue Exception => ex
      error "Failed to cretae OmfPubSubServiceHelper for PubSub server '#{@@server}' - Error: '#{ex}'"
    end

    # keep the connection to the PubSub server alive by sending a ping every hour
    # otherwise clients will be listed as "offline" in Openfire after a timeout
    Thread.new do
      while true do
        debug("XMPP server ping thread sleeping for #{PING_INTERVAL} seconds")
        sleep PING_INTERVAL
        debug("Sending a ping to the XMPP server (keepalive)")
        @service.ping
      end
    end
  end

  #
  # - Unsubscribe from all nodes
  # - Delete the PubSub user
  # - Disconnect from the PubSub server
  #
  def stop
    @service.quit if not @service.nil?
  end

  #
  # Send a message to a particular PubSub node.
  #
  def send!(message, destination)
    # Sanity checks
    if (message.length == 0) then
      error "send! -- attempted to send an empty message"
      return
    end
    if (dst.length == 0) then
      error "send! - attempted to send to an empty destination"
      return
    end
    # Build the message object
    item = Jabber::PubSub::Item.new
    msg = Jabber::Message.new(nil, message)
    item.add(msg)

    # Send the message
    debug("Send to '#{destination}' - msg: '#{message}'")
    begin
      @service.publish_to_node("#{destination}", item)
    rescue Exception => ex
      error "Failed sending to '#{destination}' - msg: '#{message}' - error: '#{ex}'"
    end
  end

  def process_event(event)
    begin
      # Ignore this 'event' if it doesnt have any 'items' element
      # These are notification messages from the PubSub server
      return if event.first_element("items") == nil

      # Retrieve the incoming PubSub Group of this message
      incoming_pubsub_node =  event.first_element("items").attributes['node']

      # Retrieve the Command Object from the received message
      info "TDEBUG - EVENT - #{event.to_s}"
      event_body = event.first_element("items").first_element("item").first_element("message").first_element("body")
      body_xml = nil
      event_body.each_element { |e| body_xml = e }
      command = OmfCommandObject.new(body_xml)
      command.pubsub_node = incoming_pubsub_node

      # Sanity checks...
      return if not should_process?(command)

      debug "Received on '#{incoming_pubsub_node}' - msg: '#{xmlMessage.to_s}'"
      # Some commands need to trigger actions on the Communicator level
      # before being passed on to the Experiment Controller
      begin
        proc = @@communicator_actions[command.cmdType]
        proc.call(command) if not proc.nil?
      rescue Exception => ex
        error "Failed to process XML message: '#{xmlMessage.to_s}' - Error: '#{ex}'"
      end

      # Now do custom processing on the command object, specific to
      # the application (EC, RC, RM, AM).
      process_command(command)
      return
    rescue Exception => ex
      error "Unknown/Wrong incoming message: '#{xmlMessage}' - Error: '#{ex}'"
      error "(Received on '#{incoming_pubsub_node}')"
      return
    end
  end

  def process_command(command)
    proc = @@command_actions[command.cmdType]
    proc.call(self, command) if not proc.nil?
  end

  def command_from_self?(command)
    commands = @@command_actions || []
    commands.include?(command.cmdType)
  end

  def command_valid?(command)
    valid_commands = @@valid_commands || []
    valid_commands.include?(command.cmdType)
  end

  def should_process?(command)
    # Ignore commands from ourselves.
    if command_from_self?(command.cmdType) then
      return false
    end

    # Alert the user if this command doesn't seem to be recognized
    # by anyone in the OMF universe.
    if not command_valid?(command.cmdType) then
      debug "Unknown command cmdType: '#{command.cmdType}' - ignoring it!"
      return false
    end
    true
  end

  def self.defCommunicatorAction(command_type, &block)
    @@communicator_actions[command_type] = block
  end

  def self.defCommandAction(command_type, &block)
    @@command_actions[command_type] = block
  end
end
