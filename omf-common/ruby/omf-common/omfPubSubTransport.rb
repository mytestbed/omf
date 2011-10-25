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
require 'omf-common/keyLocator'
require "omf-common/envelope"
require 'omf-common/mobject'

#
# This class defines a PubSub Transport
# Currently, this PubSub Transport is done over XMPP, and this class is using
# the third party library XMPP4R.
#
class OMFPubSubTransport < MObject

  include Singleton
  include OMF::Envelope
  @@started = false
  DEFAULT_PUBSUB_PWD = "123456"

  def init(opts)
    raise "PubSub Transport already started" if @@started
    @@queues = Array.new
    @@threads = Array.new
    @@qcounter = 0
    @@forceCreate = opts[:createflag]
    user = opts[:config][:xmpp][:pubsub_user] || opts[:comms_name] || 
           "#{Time.now.to_i}-#{rand(Time.now.to_i)}"
    pwd = opts[:config][:xmpp][:pubsub_pwd] || DEFAULT_PUBSUB_PWD
    @@psGateway = opts[:config][:xmpp][:pubsub_gateway]
    raise "OMFPubSubTransport - Configuration is missing 'pubsub_gateway' "+
            "parameter!" if !@@psGateway
    @@psPort = opts[:config][:xmpp][:pubsub_port]
    @@useDnsSrv = opts[:config][:xmpp][:pubsub_use_dnssrv]
    @@max_retries = opts[:config][:xmpp][:pubsub_max_retries]
    
    # Check if we are using message authentication  
    kl = nil
    aflag = opts[:config][:authenticate_messages] || false
    if aflag
      debug "Message authentication is enabled"
      raise "No private key file specified on command line or config file!" \
            if !opts[:config][:private_key]
      raise "No public key directory specified on command line or config " \
            if !opts[:config][:public_key_dir]
      kl = OMF::Security::KeyLocator.new(opts[:config][:private_key], 
                                         opts[:config][:public_key_dir])
    else
      debug "Message authentication is disabled"
    end

    # initialize message envelope generator here with kl and 
    # authenticate_messages
    OMF::Envelope.init(:authenticate_messages => aflag, :key_locator => kl)
  
    # Open a connection to the Gateway PubSub Server
    begin
      debug "Connecting to PubSub Gateway '#{@@psGateway}' as user '#{user}'"
      @@xmppServices = OmfXMPPServices.new(user, pwd, @@psGateway, @@psPort, @@useDnsSrv, @@max_retries)
    rescue Exception => ex
      raise "Failed to connect to Gateway PubSub Server '#{@@psGateway}' - "+
            "Error: '#{ex}'"
    end

    # Keep the connection to the PubSub server alive, otherwise clients will
    # be listed as "offline" by the PubSub server when idle for too long
    @@xmppServices.keep_alive
    @@started = true
    return self
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
      @@queues[index] = Queue.new
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
	debug "Creating new node '#{node}'"
	subscribed = listen(addr, &block)
      else
        raise "OMFPubSubTransport - Failed to create PubSub node '#{node}' "+
              "on '#{addr.domain}'"
      end
    end
    debug "Listening on '#{node}' at '#{addr.domain}'" if subscribed
    return subscribed
  end

  def reset
    @@xmppServices.leave_all_nodes
    @@threads.each { |t| t.exit }
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

  def send(address, msg)
    dst = address.generate_address
    domain = address.domain
    message = msg.serialize
    # Sanity checks...
    if !message || (message.length == 0)
      warn "send - Ignore attempt to send an empty message"
      return true
    end
    if !dst || (dst.length == 0 )
      warn "send - Ignore attempt to send message to nobody"
      return true
    end
    message = add_envelope(message)
    # Build Message
    item = Jabber::PubSub::Item.new
    item.add(message)
    # Send it
    debug "Send to '#{dst}' - msg: '#{message}'"
    begin
      return @@xmppServices.publish_to_node("#{dst}", domain, item)
    rescue Exception => ex
      error "Failed sending to '#{dst}' on '#{domain}'"
      error "Failed msg: '#{message}'\nError msg: '#{ex}'"
      return false
    end
  end

  def xmpp_services
    @@xmppServices
  end

  #############################
  #############################

  private

  def process_queue(event, &block)
    # Retrieve the command from the event
    message = event_to_message(event)
    return if !message

    # Pass the command to our communicator
    yield message
  end

  def event_source(event)
    begin
      source = event.first_element("items").attributes['node']
    rescue Exception => ex
      source = 'unknown'
      debug "Cannot extract source node from PubSub event - "+
            "Error: '#{ex}' - Event: '#{event}'"
    end
    return source
  end

  def event_to_message(event)
    begin
      # Ignore this 'event' if it doesnt have any 'items' element
      # These are notification messages from the PubSub server
      items = event.first_element("items")
      return nil if items.nil?

      item = items.first_element("item")
      return nil if item.nil?

      # Retrieve the payload envelope from the received message
      envelope = item.elements[1]
      # Ignore events without valid envelopes payloads
      return nil if envelope == nil
      # All good, return the extracted XML payload

      if self.verify(envelope)
        xmlMessage = self.remove_envelope(envelope)
        debug "Received on '#{event_source(event)}' - msg: '#{xmlMessage.to_s}'"
        message = get_new_message
        message.create_from(xmlMessage)
        return message
      else
        debug "Failed to verify signature - msg: '#{envelope.to_s}'"
        return nil
      end
    rescue Exception => ex
      # For now Service Calls related message are processed by their own 
      # comm stack, so ignore them here.
      return if item.first_element("service-request") || item.first_element("service-response")
      # Log an error for any other unknown events 
      debug "Cannot extract message from '#{event_source(event)}' - '#{event}'"
      debug "Error: '#{ex}'"
      #bt = ex.backtrace 
      #debug "Trace: '#{bt.join("\n\t")}'\n"
      return
    end
  end

end
