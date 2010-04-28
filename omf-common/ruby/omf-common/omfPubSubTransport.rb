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
require "omf-common/omfXMPPServices"
require "omf-common/omfPubSubMessage"
require "omf-common/omfPubSubAddress"
require 'omf-common/mobject'

# 
# This class defines a PubSub Transport  
# Currently, this PubSub Transport is done over XMPP, and this class is using
# the third party library XMPP4R.
#
class OMFPubSubTransport < MObject

  @@instance = nil
  DEFAULT_PUBSUB_PWD = "123456"
  RETRY_INTERVAL = 10

  def self.instance
    @@instance
  end

  def self.init(opts)
    raise "PubSub Transport already started" if @@instance
    @@instance = self.new
    @@queues = Array.new
    @@threads = Array.new
    @@qcounter = 0
    @@forceCreate = opts[:createflag]
    @@myName = opts[:comms_name]
    user = opts[:config][:xmpp][:pubsub_user] || 
           "#{@@myName}-#{rand(Time.now.to_i)}"
    pwd = opts[:config][:xmpp][:pubsub_pwd] || DEFAULT_PUBSUB_PWD
    @@psGateway = opts[:config][:xmpp][:pubsub_gateway]
    if !@@psGateway
      raise "OMFPubSubTransport - Configuration is missing 'pubsub_gateway' "+
            "parameter!"
    end
    
    # Open a connection to the Gateway PubSub Server
    begin
      debug "Connecting to PubSub Gateway '#{@@psGateway}' as user '#{user}'"
      check_server_reachability(@@psGateway)
      @@xmppServices = OmfXMPPServices.new(user, pwd, @@psGateway)
    rescue Exception => ex
      raise "Failed to connect to Gateway PubSub Server '#{@@psGateway}' - "+
            "Error: '#{ex}'"
    end

    # Keep the connection to the PubSub server alive by sending a ping at
    # regular intervals hour, otherwise clients will be listed as "offline" 
    # by the PubSub server (e.g. Openfire) after a timeout
    Thread.new do
      while true do
        sleep PING_INTERVAL
        debug("Sending a ping to the PubSub Gateway (keepalive)")
        @@xmppServices.ping(@@psGateway)        
      end
    end
    
    return @@instance
  end

  # NOTE: XMPP4R limitation - listening on 2 addr in the same domain - 
  # the events of the 2 listens will be put in the same Q and process by the 
  # same block, i.e. the queue and the block of the 1st call to listen!
  def listen(addr, &block)
    node = addr.generate_address
    subscribed = false
    index = 0
    # When a new event comes from that server, we push it on our event queue
    # if block has been given, create another queue and another thread 
    # to process this listening
    if block
      index = @@qcounter
      @@queues[index] << Queue.new
      @@threads << Thread.new {
        while event = @@queues[index].pop
          process_queue(event, &block)
        end
      }
      @@qcounter += 1
    end      
    subscribed = @@xmppServices.subscribe_to_node(node, addr.domain) { |event|
        @@queues[index] << event
    }         
    if !subscribed && @@forceCreate
      if @@xmppServices.create_node(node, addr.domain)
	subscribed = listen(addr, &block)
      else
        raise "OMFPubSubTransport - Failed to create PubSub node '#{node}' "+
              "on '#{addr.domain}'"
      end
    end
    return subscribed
  end

  def reset
    @@xmppServices.leave_all_nodes
    @@threads.each { |t| t.exit }
    @@queues = nil
    @@threads = nil
    @@queues = Array.new
    @@threads = Array.new
    @@qcounter = 0
  end

  def stop
    @@xmppServices.remove_all_nodes if @@forceCreate
    reset
    @@xmppServices.stop
  end

  def get_new_address(opts = nil)
    return OmfPubSubAddress.new(opts)
  end

  def get_new_message(opts = nil)
    return OmfPubSubMessage.new(opts)
  end

  #############################
  #############################
  
  private

  def send(address, message)
    dst = address.generate_address
    domain = address.domain
    # Sanity checks...
    if !message || (message.length == 0) 
      error "send - Ignore attempt to send an empty message"
      return
    end
    if !dst || (dst.length == 0 ) 
      error "send - Ignore attempt to send message to nobody"
      return
    end
    # Build Message
    item = Jabber::PubSub::Item.new
    msg = Jabber::Message.new(nil, message)
    item.add(msg)
    # Send it
    debug("send - Send to '#{dst}' - msg: '#{message}'")
    begin
      @@xmppServices.publish_to_node("#{dst}", domain, item)        
    rescue Exception => ex
      error "Failed sending to '#{dst}' on '#{serviceID}'"
      error "Failed msg: '#{message}'"
      error "Error msg: '#{ex}'"
    end
  end

  def process_queue(event, &block)
    # Retrieve the command from the event
    cmdObj = event_to_message(event)
    return if !cmdObj

    # Pass the command to our communicator
    yield cmdObj
  end

  def check_server_reachability(server)
    check = false
    while !check
      reply = `ping -c 1 #{server}`
      if $?.success?
        check = true
      else
        info "Could not resolve or contact: '#{server}'"+ 
	      "Waiting #{RETRY_INTERVAL} sec before retrying..."
        sleep RETRY_INTERVAL
      end
    end
  end

  def event_source(event)
    return event.first_element("items").attributes['node']
  end

  def event_to_message(event)
    begin
      # Ignore this 'event' if it doesnt have any 'items' element
      # These are notification messages from the PubSub server
      return nil if event.first_element("items") == nil
      return nil if event.first_element("items").first_element("item") == nil
      # Retrieve the Command Object from the received message
      eventBody = event.first_element("items").first_element("item").\
                  first_element("message").first_element("body")
      xmlMessage = nil
      eventBody.each_element { |e| xmlMessage = e }
      # Ignore events without XML payloads
      return nil if xmlMessage == nil 
      # All good, return the extracted XML payload
      debug "Received on '#{event_source(event)}' - msg: '#{xmlMessage.to_s}'"
      return xmlMessage
    rescue Exception => ex
      error "Cannot extract command from PubSub event '#{eventBody}'"
      error "Error: '#{ex}'"
      error "Event was received on '#{event_source(event)}')" 
      return
    end
  end

end
