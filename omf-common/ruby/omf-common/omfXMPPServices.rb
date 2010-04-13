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
# Implementation Note: after testing interaction XMPP4R + OpenFire, it seems
# like separate instances of Jabber::Client to perform publish/subscribe tasks 
# and PubSub node browsing tasks. When using a unique instance to perform both 
# type of tasks, the test application was always freezing...
#
# NOTE: Extensive modification by TR from the original code from Javid
# TODO: Remove or Comment debug messages marked as 'TDEBUG'
#

require "xmpp4r"
require "xmpp4r/pubsub"
require "xmpp4r/pubsub/helper/servicehelper"
require 'omf-common/mobject'
#Jabber::debug = true

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

  #
  # Create a new instance of XMPP Services 
  # This instance will maintain a single connection to a 'home' XMPP server
  # and potentially multiple 'service helpers' to access other XMPP server
  # via Server2Server communication.
  # 
  # - user = [String] username to connect to the home XMPP server  
  # - password = [String], password to connect to the home XMPP server
  # - host = [String] hostname of the home XMPP server   
  #
  def initialize(user, password, host)

    # Set internal attributes
    @userJID = "#{user}@#{host}"
    @password = password
    @homeServer = host
    @homeJID = "pubsub.#{host}"
    @serviceHelpers = Hash.new # Holds the list of service helpers

    # Open a connection to the home XMPP Server
    # Any exception raised here shall be caught by the caller
    @clientHelper = Jabber::Client.new(@userJID)
    # We are passing the hostname here to prevent xmpp4r from trying to resolve
    # the DNS SRV record
    @clientHelper.connect(@homeServer)
    # First, we try to register a new user at the server for this client
    # (assumes that the XMPP server is allowing in-band user registration)
    begin
      @clientHelper.register(@password)
    rescue Exception => ex
      # if the user already exists at the server side, then we receive an error
      # 409 ("conflict:") which we will ignore, all other errors are reported
      if ("#{ex}" != "conflict: ")
        then raise "OmfXMPPServices - Failed to register user '#{@userJID}' - Error: '#{ex}'"
      end
    end
    # Now, we authenticate this client to the server
    @clientHelper.auth(password)
    @clientHelper.send(Jabber::Presence.new)
    debug "Connection opened to XMPP server: '#{@homeServer}'"
  end

  #
  # Create a new Service Helper to interact with a given XMPP server.
  # The server is identified by its JID (Jabber ID), and the communication is
  # either done directly (if it is our home XMPP server) or via the XMPP
  # Server2Server capability (if it is a remote XMPP server).
  #
  # - serviceID = [String|Symbol] a name for this service
  # - serverJID = [String] a JID for the server to interact with, following the
  #               XMPP convention, this JID should start with "pubsub."
  # - &bock = the block of commands that will process any event coming from that
  #           XMPP server
  #
  def add_new_service(serviceID, serverJID, &block)
    begin
      @serviceHelpers[serviceID] = OmfServiceHelper.new(@clientHelper, serverJID)
    rescue  Exception => ex
      raise "OmfXMPPServices - Failed to create service to '#{serverJID}' - Error: '#{ex}'"
    end
    begin
      @serviceHelpers[serviceID].add_event_callback(&block)
    rescue Exception => ex
      raise "OmfXMPPServices - Failed to register event callback - Error: '#{ex}'"
    end
  end

  #
  # Wrapper around the getter for the list of service helpers.
  # We wrap this default getter so that an exception is raised if the service
  # is unknown to us.
  #
  # - serviceID =  [String|Symbol] the ID of the service helper to return
  #
  # [Return] a OmfServiceHelper object
  #
  def service(serviceID)
    serv = @serviceHelpers[:serviceID] 
    if !serv
      raise "OmfXMPPServices - Unknown service '#{serviceID}'"
    end
    return serv
  end

  #
  # Create a new PubSub node on the home or a remote XMPP server.
  # Do nothing if the PubSub node already exists. Openfire automatically adds 
  # the creator of the node to the subscriber list and does not allow it to
  # unsubscribe. Ejabberd does not do that. To stay compatible with openfire, 
  # we replicate its behaviour by subscribing to the node we create.
  #
  # - node = [String] name of the node to create
  # - serviceID = [String|Symbol] the serviceID for the the server on which
  #               we want to create this node 
  #
  # [Return] True/False
  #
  def create_pubsub_node(node, serviceID)
    begin
      service(serviceID).create_node(node,Jabber::PubSub::NodeConfig.new(nil,{
        "pubsub#title" => "#{node}",
        "pubsub#node_type" => "leaf",
        "pubsub#persist_items" => "1",
        "pubsub#max_items" => "1",
        "pubsub#notify_retract" => "0",
        "pubsub#publish_model" => "open"}))
    rescue Exception => ex
      # if the node exists we ignore the "conflict" exception
      return true if ("#{ex}" == "conflict: ")
      raise "OmfXMPPServices - Failed creating node '#{node}'- Error: '#{ex}'"
    end
    # openfire subscribes us automatically, so this is just for ejabberd:
    join_pubsub_node(node, serviceID)
    return true
  end

  #
  # Remove a PubSub node. 
  # Do nothing if the PubSub node doesn't exist
  #
  # - node = [String] name of the node to remove
  # - serviceID = [String|Symbol] the serviceID for the the server on which
  #               we want to remove this node
  #
  # [Return] True/False
  #
  def remove_pubsub_node(node, serviceID)
    begin
      service(serviceID).delete_node(node)
    rescue Exception => ex
      # if the PubSub node does not exist, we ignore the "not found" exception
      return true if ("#{ex}" == "item-not-found: ")
      raise "OmfXMPPServices - Failed removing node '#{node}'- Error: '#{ex}'"
    end
    return true
  end

  #
  # Publish a new message (item) to a PubSub node
  #
  # - node = [String] name of the PubSub node 
  # - item = [Jabber::item] the PubSub item to publish
  # - serviceID = [String|Symbol] the serviceID for the the server on which
  #               we want to publish to this node
  #
  def publish_to_node(node, item, serviceID)
    begin
      service(serviceID).publish_item_to(node,item)
    rescue Exception => ex
      if ("#{ex}"=="item-not-found: ")
        debug "OmfXMPPServices - Failed publishing to unknown node '#{node}' "+
              "on service '#{serviceID}'"
        return false
      end
      raise "OmfXMPPServices - Failed publishing to node '#{node}' "+
            "on service '#{serviceID}' - Error: '#{ex}'"
    end
    return true
  end

  #
  # Subscribe to a PubSub node
  # Do nothing if the node does not exist or if we are already subscribed
  #
  # - node = [String] name of the PubSub node 
  # - serviceID = [String|Symbol] the serviceID for the the server on which
  #               we want to publish to this node
  #
  def join_pubsub_node(node, serviceID)
    begin
      service(serviceID).subscribe_to(node)
    rescue Exception => ex
      if ("#{ex}"=="item-not-found: ")
        debug "OmfXMPPServices - Failed subscribing to unknown node '#{node}' "+
              "on service '#{serviceID}'"
        return false
      end
      raise "OmfXMPPServices - Failed subscribing to node '#{node}' "+
            "on service '#{serviceID}' - Error: '#{ex}'"
    end
    return true
  end

  #
  # Unsubscribe from a given PubSub node
  #
  # - node = [String] name of the PubSub node 
  # - subid = the subscription ID for this PubSub node
  # - serviceID = [String|Symbol] the serviceID for the the server on which
  #               we want to unsubscribe from this node
  #
  def leave_pubsub_node(node, subid, serviceID)
    begin
      service(serviceID).unsubscribe_from_fixed(node, subid)
    rescue Exception => ex
      if ("#{ex}"=="item-not-found: ")
        debug "OmfXMPPServices - Failed unsubscribing to unknown node '#{node}' "+
              "on service '#{serviceID}'"
        return false
      end
      raise "OmfXMPPServices - Failed unsubscribing to node '#{node}' "+
            "on service '#{serviceID}' - Error: '#{ex}'"
    end
    return true
  end

  #
  # Returns all subscriptions for a given service helper 
  #
  # - serviceID = [String|Symbol] the serviceID for the the server on which
  #               we want to get the list of all subscribed nodes
  #
  # [Return] Hash of Strings
  #
  def list_all_subscriptions(serviceID)
    list = []
    begin
      list = service(serviceID).get_subscriptions_from_all_nodes
    rescue Exception => ex
      raise "OmfXMPPServices - Failed getting list of all subscribed nodes "+
            "for service '#{serviceID}' - ERROR - '#{ex}'"
    end
    list
  end

  #
  # Unsubscribe from all PubSub nodes on a given server
  #
  # - serviceID = [String|Symbol] the serviceID for the the server on which
  #               we want to unsubscribe from all nodes
  #
  def leave_all_pubsub_nodes(serviceID)
    list_all_subscriptions(serviceID).each { |sub|
      leave_pubsub_node(sub.node, sub.subid, serviceID)
    }
  end

  #
  # Remove all PubSub nodes currently subscribed to on a given server
  #
  # - serviceID = [String|Symbol] the serviceID for the the server on which
  #               we want to remove all nodes
  #
  def remove_all_pubsub_nodes()
    list_all_subscriptions(serviceID).each { |sub|
      remove_pubsub_node(sub.node, serviceID)
    }
  end

  #
  # Send a ping to the PubSub server
  #
  # - serviceID = [String|Symbol] the serviceID for the the server to ping
  #
  def ping(serviceID)
    begin
      service(serviceID).ping
    rescue Exception => ex
      raise "OmfXMPPServices - Failed 'pinging' service '#{serviceID}' - Error: '#{ex}'"
    end
  end

  #
  # Remove all PubSub nodes currently subscribed to
  # Delete the PubSub user
  # Close the connection to the PubSub server
  #
  def quit()
    debug "OmfXMPPServices - Cleaning and Exiting!"
    @serviceHelpers.each { |serv|
      leave_all_pubsub_nodes(serv)
    }
    @clientHelper.remove_registration
    @clientHelper.close
  end
    
end
