#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
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
# = omfXMPPServices.rb
#
# == Description
#
# This file implements 
#
# a Publish/Subscribe Service Helper.
# This PubSub Service Helper is based on XMPP.
# This current implementation uses the library XMPP4R.
#

require 'rubygems'
gem 'xmpp4r', '=0.5'
require 'xmpp4r'
require 'xmpp4r/pubsub'
require 'xmpp4r/pubsub/helper/servicehelper'
require 'xmpp4r/pubsub/helper/nodebrowser'
require 'omf-common/mobject'
#Jabber::debug = true

GATEWAY_TIMEOUT = 30 # in sec
RECONNECT_INTERVAL = 10 # in sec
PING_INTERVAL = 60 # in sec
PING_ATTEMPTS = 10 # in number of pings

#
# This class subclasses 'Jabber::PubSub::ServiceHelper' because its 
# 'unsubscribe_from' method is broken. 
# Indeed, as stated in the XMPP4R v0.4 API, it does NOT support the 'subid' 
# field. However, the OpenFire v3.6 server (which we currently use as XMPP 
# Server) requires the use of that field to process unsubsribe requests, 
# otherwise it replies with a 'Bad request' error.
# This class also implements a 'ping' back to the XMPP server, as defined
# in http://xmpp.org/extensions/xep-0199.html#c2s
#
class OmfServiceHelper < Jabber::PubSub::ServiceHelper

  #
  # Perform a 'unsubscribe_from' from scratch
  #
  def unsubscribe_from_fixed (node,subid)
    iq = basic_pubsub_query(:set)
    sub = REXML::Element.new('unsubscribe')
    sub.attributes['node'] = node
    sub.attributes['jid'] = @stream.jid.strip.to_s
    sub.attributes['subid']=subid
    iq.pubsub.add(sub)
    ret = false
    @stream.send_with_id(iq) do |reply|
      ret = reply.kind_of?(Jabber::Iq) and reply.type == :result
    end # @stream.send_with_id(iq)
    ret  
  end
  
  #
  # Send a ping to the PubSub server
  # implemented according to
  # http://xmpp.org/extensions/xep-0199.html#c2s
  #
  def ping
    iq = Jabber::Iq.new(:get, @stream.jid.domain)
    iq.from = @stream.jid
    ping = iq.add(REXML::Element.new('ping'))
    ping.add_namespace 'urn:xmpp:ping'
    @stream.send_with_id(iq) do |reply|
      ret = reply.kind_of?(Jabber::Iq) and reply.type == :result
    end # @stream.send_with_id(iq)
  end
  
  #
  # Another bug in XMPP4r
  # owner field is missing when purging items
  # see http://www.ejabberd.im/node/3413
  #
  def purge_items_from(node)
    iq = basic_pubsub_query(:set,true)
    purge = REXML::Element.new('purge')
    purge.attributes['node'] = node
    iq.pubsub.add(purge)
    @stream.send_with_id(iq)
  end

  def stream
    @stream
  end
end # END of OmfServiceHelper


# 
# This class defines a XMPP Service Helper for OMF entities.
# Following the PubSub communication paradigm, this class will be the
# 'XMPP Client' which will talk to an 'XMPP Server'. So far, we have tested
# this class with OpenFire (v3.6) and EJabberd XMPP servers.
# This Service Helper will handle all messages to and from the XMPP Server.
# Following the XMPP4R scheme, this class holds a single connection to a
# main (or 'home') XMPP server, and potentially several 'service helpers'
# which are used to access other XMPP servers via 'home' server and the 
# XMPP Server2Server capability.
#
class OmfXMPPServices < MObject

  @clientHelper = nil
  @nodeBrowser = nil

  attr_reader :clientHelper

  #
  # Create a new instance of XMPP Services 
  # This instance will maintain a single connection to a 'home' XMPP server
  # and will serve as an entry-point into the XMPP world to interact with 
  # potentially multiple XMPP servers via Server2Server communication.
  # A 'service helper' will be required for each XMPP server we want to
  # interact with (see the 'add_service' method)
  # 
  # - user = [String] username to connect to the home XMPP server  
  # - password = [String], password to connect to the home XMPP server
  # - host = [String] hostname of the home XMPP server   
  # - port = [Fixnum] optional port number of the home XMPP server
  # - useDnsSrv = [Bool] optional flag to enable DNS SRV record resolution
  #
  def initialize(user, password, host, port = nil, useDnsSrv = nil, max_retries = nil)

    # Set internal attributes
    @userJID = "#{user}@#{host}"
    @password = password
    @homeServer = host
    @port = port || 5222
    @useDnsSrv = useDnsSrv || false
    @max_retries = max_retries || 0
    @serviceHelpers = Hash.new # Holds the list of service helpers
    @connecting = false
    @keepAliveThread = nil
    @cSemaphore = Mutex.new

    # Open a connection to the home XMPP Server
    # Any exception raised here shall be caught by the caller
    @clientHelper = Jabber::Client.new(@userJID)
    connect
    @clientHelper.on_exception { connect }
  end

  def connect
    # Only allow one connection attempt at a time! 
    @cSemaphore.synchronize {
      return if @connecting 
      @connecting = true
    }
    @connection_attempts = 1
    # In case "connect" was called even though we are already connected
    # try close the connection first.
    # Ignore any exception in doing so (e.g. if there is no previous connection)
    begin 
      @clientHelper.close if !@clientHelper.nil?
    rescue Exception => ex
      debug "Cannot close a previous (if any) connection to PubSub Gateway '#{@homeServer}'"
    end
    @connection_attempts = 0
    debug "Trying to connect to Pubsub Gateway '#{@homeServer}:#{@port}'..."
    begin
      @connection_attempts+=1
      success = call_with_timeout("Timeout while connecting to "+
                                  "PubSub Gateway '#{@homeServer}'") { 
                                    if @useDnsSrv
                                      # passing no hostname here will try to resolve a DNS
                                      # SRV record through the host part of the JID
                                      @clientHelper.connect(nil, @port)
                                    else
                                      # passing a hostname disables DNS SRV queries
                                      @clientHelper.connect(@homeServer, @port)
                                    end }
      raise Exception.new if !success
    rescue Exception => ex
      raise Exception.new("Maximum number of connection attempts reached") if @connection_attempts == @max_retries
      debug "Cannot connect to PubSub Gateway '#{@homeServer}'! "+
            "Retry in #{RECONNECT_INTERVAL}s ..."
      sleep RECONNECT_INTERVAL
      retry
    end 
    # First, we try to register a new user at the server for this client
    # (assumes that the XMPP server is allowing in-band user registration)
    begin
      @clientHelper.register(@password)
    rescue Exception => ex
      # if the user already exists at the server side, then we receive an error
      # 409 ("conflict:") which we will ignore, all other errors are reported
      if ("#{ex}" != "conflict: ")
        then raise "OmfXMPPServices - Failed to register user '#{@userJID}' "+
                   "- Error: '#{ex}'"
      end
    end
    # Now, we authenticate this client to the server
    @clientHelper.auth(@password)
    @clientHelper.send(Jabber::Presence.new)
    debug "Connected as '#{@userJID}' to XMPP server: '#{@homeServer}'"
    @nodeBrowser = Jabber::PubSub::NodeBrowser.new(@clientHelper)
    @cSemaphore.synchronize {
      @connecting = false
    }
  end

  def call_with_timeout(message, &block)
    callingThread = Thread.new(&block) 
    success = callingThread.join(GATEWAY_TIMEOUT) 
    if !success
      callingThread.kill!
      warn "#{message}"
    end
    return success
  end

  # Keep the connection to the PubSub server alive by sending a ping at
  # regular intervals, otherwise clients will be listed as "offline" 
  # by the PubSub server (e.g. Openfire) after a timeout
  # if PING_ATTEMPTS pings in a row fail, then try to reconnect
  def keep_alive
    @keepAliveThread = Thread.new do
      while true do
        @pingTries = 0
        @pingThread = Thread.new do
          while true do
            sleep PING_INTERVAL
            #debug "Ping the PubSub Gateway (keepalive)"
            success = ping(@homeServer)
            # Kill this ping Thread if too many ping failures
            @pingTries += 1 if !success
            @pingTries = 0 if success
            if @pingTries >= PING_ATTEMPTS 
              debug "No reply to XMPP pings was received, attempting to reconnect..."
              break 
            end
          end
        end # ping Thread
        # Join the ping Thread, if it dies then try to reconnect
        @pingThread.join
        connect
      end # while
    end # keepAliveThread
  end

  #
  # Create a new Service Helper to interact with a given XMPP server.
  # The server is identified by its JID (Jabber ID), and the communication is
  # either done directly (if it is our home XMPP server) or via the XMPP
  # Server2Server capability (if it is a remote XMPP server).
  #
  # - domain = [String|Symbol] a name for this service
  # - serverID = [String] a ID for the server to interact with, following the
  #               XMPP convention we will prefix this ID with "pubsub."
  # - &block = the block of commands that will process any event coming from that
  #           XMPP server
  #
  def add_service(domain, &block)
    begin
      @serviceHelpers[domain] = OmfServiceHelper.new(@clientHelper, 
                                                     "pubsub.#{domain}")
    rescue  Exception => ex
      raise "OmfXMPPServices - Failed to create service to '#{domain}' "+
	    "- Error: '#{ex}'"
    end
    leave_all_nodes(domain)
    begin
      @serviceHelpers[domain].add_event_callback(&block) if block
    rescue Exception => ex
      raise "OmfXMPPServices - Failed to register event callback for domain "+
            "'#{domain}' - Error: '#{ex}'"
    end
  end

  #
  # Wrapper around the getter for the list of service helpers.
  # We wrap this default getter so that an exception is raised if the service
  # is unknown to us.
  #
  # - domain =  [String|Symbol] the ID of the service helper to return
  #
  # [Return] a OmfServiceHelper object
  #
  def service(domain)
    serv = @serviceHelpers[domain] 
    if !serv
      raise "OmfXMPPServices - Unknown domain '#{domain}'"
    end
    return serv
  end

  def service?(domain)
    return true if @serviceHelpers[domain]    
    return false
  end

  #
  # Create a new PubSub node on the home or a remote XMPP server.
  # Do nothing if the PubSub node already exists. Openfire automatically adds 
  # the creator of the node to the subscriber list and does not allow it to
  # unsubscribe. Ejabberd does not do that. To stay compatible with openfire, 
  # we replicate its behaviour by subscribing to the node we create.
  #
  # - node = [String] name of the node to create
  # - domain = [String|Symbol] the domain for the the server on which
  #               we want to create this node 
  #
  # [Return] True/False
  #
  def create_node(node, domain)
    begin
      add_service(domain) if !service?(domain)
      service(domain).create_node(node,Jabber::PubSub::NodeConfig.new(nil,{
        "pubsub#title" => "#{node}",
        "pubsub#node_type" => "leaf",
        # turns off delayed message delivery and message caching
        "pubsub#persist_items" => "0",
        # has no effect, OF always sets this to 1
        "pubsub#max_items" => "0",
        "pubsub#notify_retract" => "0",
        "pubsub#publish_model" => "open",
        # has not effect, will still deliver item in OF. Also deprecated in the spec.
        "pubsub#send_item_subscribe" => "0"}))
    rescue Exception => ex
      # if the node exists we ignore the "conflict" exception
      return true if ("#{ex}" == "conflict: ")
      raise "OmfXMPPServices - Failed creating node '#{node}' on domain "+
            "#{domain} - Error: '#{ex}'"
    end
    return true
  end

  #
  # Publish a new message (item) to a PubSub node
  #
  # - node = [String] name of the PubSub node 
  # - item = [Jabber::item] the PubSub item to publish
  # - domain = [String|Symbol] the domain for the the server on which
  #               we want to publish to this node
  # - create_if_not_exist = [bool] Create +node+ if not exist
  #
  def publish_to_node(node, domain, item, create_if_not_exist = false)
    begin
      add_service(domain) if !service?(domain)
      success = call_with_timeout("Timeout out while sending PubSub message to "+
                        "'#{domain}'") { 
                        service(domain).publish_item_to(node, item) }
      return false if !success
      return true
    rescue Exception => ex
      if ("#{ex}"=="item-not-found: ")
        if create_if_not_exist
          create_node(node, domain)
          return publish_to_node(node, domain, item, false) # false to avoid infinite loop
        end
        warn "Failed publishing to unknown node '#{node}' "+
              "on domain '#{domain}'"
        return false
      end
      if ("#{ex}"=="forbidden: ")
        warn "Not allowed to publish to node '#{node}' "+
              "on domain '#{domain}'"
        return false
      end
      raise "OmfXMPPServices - Failed publishing to node '#{node}' "+
            "on domain '#{domain}' - Error: '#{ex}'"
    end
  end

  #
  # Subscribe to a PubSub node
  # Do nothing if the node does not exist or if we are already subscribed
  #
  # - node = [String] name of the PubSub node 
  # - domain = [String|Symbol] the domain for the the server on which
  #               we want to publish to this node
  #
  def subscribe_to_node(node, domain, &block)
    begin
      add_service(domain, &block) if !service?(domain)
      service(domain).subscribe_to(node)
    rescue Exception => ex
      if ("#{ex}"=="item-not-found: ")
        debug "Could not subscribe to unknown node '#{node}' "+
              "on domain '#{domain}'"
        return false
      end
      raise "OmfXMPPServices - Failed subscribing to node '#{node}' "+
            "on domain '#{domain}' - Error: '#{ex}'"
    end
    return true
  end

  #
  # Returns all subscriptions for a given service helper 
  #
  # - domain = [String|Symbol] the domain for the the server on which
  #               we want to get the list of all subscribed nodes
  #
  # [Return] Hash of Strings
  #
  def list_all_subscriptions(domain)
    list = []
    begin
      call_with_timeout("Timeout out while getting all subscriptions on '#{domain}'") do
        list = service(domain).get_subscriptions_from_all_nodes
      end
    rescue Exception => ex
      raise "OmfXMPPServices - Failed getting list of all subscribed nodes "+
            "for domain '#{domain}' - ERROR - '#{ex}'"
    end
    list
  end

  #
  # Unsubscribe from a given PubSub node
  #
  # - node = [String] name of the PubSub node 
  # - subid = the subscription ID for this PubSub node
  # - domain = [String|Symbol] the domain for the the server on which
  #               we want to unsubscribe from this node
  #
  def leave_node(node, subid = nil, domain = nil)
    @serviceHelpers.each { |dom, helper| leave_node(node, subid, dom) } if domain.nil?
    if subid.nil?
      list_all_subscriptions(domain).each do |sub| 
        leave_node(sub.node, sub.subid, domain) if sub.node == node 
      end
    end
    begin
      call_with_timeout("Timeout out while leaving the PubSub node '#{node}'") do
        service(domain).unsubscribe_from_fixed(node, subid) 
      end
    rescue Exception => ex
      if ("#{ex}" == "item-not-found: ")
        debug "Failed unsubscribing to unknown node '#{node}' "+
              "on domain '#{domain}'"
      elsif ("#{ex}"=="unexpected-request: ")
        debug "leave_pubsub_node - Unsubscribing from node '#{node}' failed as there was no subscription."
      else
        raise "OmfXMPPServices - Failed unsubscribing to node '#{node}' "+
              "on domain '#{domain}' - Error: '#{ex}'"
      end
    end
  end

  #
  # Unsubscribe from all PubSub nodes on a given server
  #
  # - domain = [String|Symbol] the domain for the the server on which
  #               we want to unsubscribe from all nodes
  #
  def leave_all_nodes(domain = nil)
    if domain
      list_all_subscriptions(domain).each { |sub|
        leave_node(sub.node, sub.subid, domain)
      }
    else
      @serviceHelpers.each { |dom, helper| leave_all_nodes(dom) }
    end
  end

  #
  # Purge all items from a PubSub node. 
  # Do nothing if the PubSub node doesn't exist
  #
  # - node = [String] name of the node to remove
  # - domain = [String|Symbol] the domain for the the server on which
  #               we want to purge this node
  #
  # [Return] True/False
  #
  def purge_node(node, domain)
    begin
      call_with_timeout("Timeout out while purging the PubSub node '#{node}'") {
                        service(domain).purge_items_from(node) }
    rescue Exception => ex
      # if the PubSub node does not exist, we ignore the "not found" exception
      return true if ("#{ex}" == "item-not-found: ")
      return true if ("#{ex}" == "forbidden: ")
      error "Failed purging node '#{node}'- Error: '#{ex}'"
      return false
    end
    return true
  end

  #
  # Remove a PubSub node. 
  # Do nothing if the PubSub node doesn't exist
  #
  # - node = [String] name of the node to remove
  # - domain = [String|Symbol] the domain for the the server on which
  #               we want to remove this node
  #
  # [Return] True/False
  #
  def remove_node(node, domain)
    purge_node(node, domain)
    begin
      call_with_timeout("Timeout out while removing the PubSub node '#{node}'") {
                        service(domain).delete_node(node) }
    rescue Exception => ex
      # if the PubSub node does not exist, we ignore the "not found" exception
      return true if ("#{ex}" == "item-not-found: ")
      return true if ("#{ex}" == "forbidden: ")
      error "Failed removing node '#{node}'- Error: '#{ex}'"
      return false
    end
    return true
  end

  #
  # Remove all PubSub nodes currently subscribed to on a given server
  #
  # - domain = [String|Symbol] the domain for the the server on which
  #               we want to remove all nodes
  #
  def remove_all_nodes(domain = nil)
    if domain
      list_all_subscriptions(domain).each { |sub|
        leave_node(sub.node, sub.subid, domain)
        remove_node(sub.node, domain)
      }
    else
      @serviceHelpers.each { |dom, helper| remove_all_nodes(dom) }
    end
  end

  #
  # Send a ping to the PubSub server
  #
  # - domain = [String|Symbol] the domain for the the server to ping
  #
  def ping(domain)
    begin
      s = call_with_timeout("Timeout while pinging the PubSub Gateway "+
                        "'#{domain}'") { service(domain).ping }
      return s
    rescue Exception => ex
      warn "Cannot ping the Pubsub Gateway '#{ping}'!"
      return nil
      # let the reconnection thread handle the rest...
    end
  end

  #
  # Leave all PubSub nodes currently subscribed to
  # Delete the PubSub user
  # Close the connection to the PubSub server
  #
  def stop
    debug "Exiting!"
    begin
      @keepAliveThread.kill! if @keepAliveThread
      call_with_timeout("Timeout closing connection to the PubSub Gateway "+
                        "'#{@homeServer}}'") { 
                        @clientHelper.remove_registration
                        @clientHelper.close
      }
    # Do not care if an error occured during stopping
    rescue Exception => ex
      warn "Failed to exit cleanly (error: '#{ex}')"
    end
  end
  
  # returns all pubsub nodes a given XMPP domain
  def list_nodes(domain)
    nodes = []
    begin
      nodes = @nodeBrowser.nodes("pubsub.#{domain}")
    rescue Exception => ex
      warn "Failed to retrieve list of pubsub nodes (error: '#{ex}')"
    end
    nodes
  end
    
end
