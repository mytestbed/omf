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
# = omfPubSubService.rb
#
# == Description
#
# This file implements a Publish/Subscribe Service Helper.
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
require "xmpp4r/pubsub/helper/nodebrowser"
require 'omf-common/mobject'

#
# This class subclasses 'Jabber::PubSub::ServiceHelper' because its 
# 'unsubscribe_from' method is broken. Indeed, as stated in the XMPP4R v0.4 API, 
# it does NOT support the 'subid' field. However, the OpenFire v3.6 server (which
# we currently use as XMPP Server) requires the use of that field to process 
# unsubsribe requests, otherwise it replies with a 'Bad request' error.
#
class MyServiceHelper < Jabber::PubSub::ServiceHelper
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
end

# 
# This class defines a PubSub Service Helper for OMF entities.
# Following the PubSub communication paradigm, this class will be the
# 'XMPP Client' which will talk to an 'XMPP Server'. Currently, we are 
# using OpenFire v3.6 as the 'XMPP Server'.
# This Service Helper will handle all messages to and from the XMPP Server.
#
class OmfPubSubService < MObject
        
  #
  # Create a new instance of PubSub Service Helper
  # (JID = Jabber ID)
  # 
  # - userjid = [String] or [Jabber::JID], JID to use to connect to the PubSub Server
  # - password = [String], password to use for this PubSud client
  # - pubsubjid = [String] or [Jabber::JID], JID of the PubSub Server 
  #
  def initialize(userjid, password, pubsubjid)
    # Set internal attributes
    @userJID = userjid
    @password = password
    @pubsubjid = pubsubjid
  
    # First open a connection for this Helper to interact with the PubSub Server
    # Any exception raised here will be caught by the Communicator
    @clientHelper = Jabber::Client.new(userjid)
    @clientHelper.connect
    begin
      @clientHelper.register(password)
    # if the user already exists, we receive an error 409 ("conflict: ") and ignore it
    # otherwise we report it
    rescue Exception => ex
      if ("#{ex}" != "conflict: ")
        then debug "CDEBUG - Failed to register user #{@userJID} - Error: '#{ex}'"
      end
    end
    @clientHelper.auth(password)
    @clientHelper.send(Jabber::Presence.new)
  
    # Then open another connection for the Browser to interact with the PubSub Server
    # Any exception raised here will be caught by the Communicator
    # Note: as of XMPP4R v0.4 and OpenFire 3.6, two separate connections are needed
    # for the Helper and the Browser.
    @clientBrowser = Jabber::Client.new(userjid)
    @clientBrowser.connect
    @clientBrowser.auth(password)
    @clientBrowser.send(Jabber::Presence.new)
  
    # Finally create this Helper and its Browser    
    @browser = Jabber::PubSub::NodeBrowser.new(@clientBrowser)
    @service = MyServiceHelper.new(@clientHelper, @pubsubjid)
  end
  
  #
  # Set callback for incoming message (i.e. "PubSub events")
  #
  # - &bock = the block of commands that will process the message
  #
  def add_event_callback (&block)
    begin
      @service.add_event_callback(&block)
    rescue Exception => ex
      error "add_event_callback - Error registering callback - '#{ex}'"
    end
  end

  #
  # Create a PubSub node (aka group, or discussion board)
  # Do nothing if the PubSub node already exists
  # Openfire automatically adds the creator of the node
  # to the subscriber list and does not allow it to
  # unsubscribe.
  #
  # - node = [String] name of the node to create
  #
  # [Return] True/False
  #
  def create_pubsub_node(node)
    if node_exist?(node)
      info "Node #{node} already exists"
      flag=false
    else
      @service.create_node(node,Jabber::PubSub::NodeConfig.new(nil,{
                           "pubsub#title" => "#{node}",
                           "pubsub#node_type" => "leaf",
                           "pubsub#send_item_subscribe" => "1",
                           "pubsub#publish_model" => "open"}))
      info "Node #{node} was created"  
      flag=true
    end
    flag
  end

  #
  # Remove a PubSub node (aka group, or discussion board)
  # Do nothing if the PubSub node doesn't exist
  #
  # - node = [String] name of the node to remove
  #
  # [Return] True/False
  #
  def remove_pubsub_node(node)
    if !node_exist?(node)
      info "Node #{node} doesn't exist"
      flag=false
    else
      begin
        @service.delete_node(node)
      rescue
      end
      info "Node #{node} was removed"
      flag=true
    end
    flag
  end
        
  #
  # Publish a new message (item) to a PubSub node
  #
  # - node = [String] name of the PubSub node 
  # - item = [Jabber::item] the PubSub item to publish
  #
  def publish_to_node(node,item)
    if !node_exist?(node)
      debug "publish_to_node - Node does not exist!  '#{node}'"
    else
      #debug "publish_to_node - A"
      @service.publish_item_to(node,item)
      #debug "publish_to_node - B"
    end
  end

  #
  # Unsubscribe from all PubSub nodes
  #
  def leave_all_pubsub_nodes()
    listAllSubscription = get_all_pubsub_subscriptions
    debug "TDEBUG - List BEFORE Leaving all: #{listAllSubscription}"
    listAllSubscription.each { |sub|
      leave_pubsub_node(sub.node, sub.subid)
    }
      debug "TDEBUG - LIST AFTER Leaving - #{get_all_pubsub_subscriptions}"
  end
  
  #
  # Unsubscribe from all PubSub nodes except the ones containing the substring 'prefix'
  #
  def leave_all_pubsub_nodes_except(prefix)
    listAllSubscription = get_all_pubsub_subscriptions
    debug "TDEBUG - List BEFORE Leaving all except the ones containing '#{prefix}: #{listAllSubscription}'"
    listAllSubscription.each { |sub|
      if (!sub.node.include? prefix) 
        then leave_pubsub_node(sub.node, sub.subid)
     end
    }
    debug "TDEBUG - LIST AFTER Leaving - #{get_all_pubsub_subscriptions}"
  end
  
  #
  # Remove all PubSub nodes currently subscribed to
  #
  def remove_all_pubsub_nodes()
    listAllSubscription = get_all_pubsub_subscriptions
    #debug "CDEBUG - List BEFORE Removing All: #{listAllSubscription}"
    listAllSubscription.each { |sub|
      begin
        @service.delete_node(sub.node)
      rescue
      end
    }
    #debug "CDEBUG - LIST AFTER Removing - #{get_all_pubsub_subscriptions}"
  end
  
  #
  # Remove all PubSub nodes currently subscribed to
  # Delete the PubSub user
  # Close the connection to the PubSub server
  #
  def quit()
    leave_all_pubsub_nodes
    debug "CDEBUG - quit - removing user from PubSub server and closing connection"
    @clientHelper.remove_registration
    @clientHelper.close
    @clientBrowser.close
  end
  
  #
  # Unsubscribe from a given PubSub node
  #
  # - node = [String] name of the PubSub node 
  # - subid = the subscription ID for this PubSub node
  #
  def leave_pubsub_node(node, subid)
    if !node_exist?(node)
      debug "TDEBUG - leave_pubsub_node - Node does not exist!  '#{node}'"
    else
      debug "TDEBUG - Leaving PubSub node: #{node} - #{subid}"
      @service.unsubscribe_from_fixed(node, subid)
      debug "TDEBUG - Leaving PubSub node: #{node} - #{subid} - done"
    end
  end
	
  #
  # Subscribe to a PubSub node
  # Do nothing if the node does not exist or if we are already subscribed
  #
  # - node = [String] name of the PubSub node 
  #
  def join_pubsub_node(node)
    debug "TDEBUG - join_pubsub_node - called with: '#{node}'"
    #debug "TDEBUG - LIST BEFORE JOIN - #{get_all_pubsub_subscriptions}"
    # Check if this node already exist
    if !node_exist?(node)
      debug "TDEBUG - join_pubsub_node - Node does not exist!  '#{node}'"
    else
      # If not, subscribe to it, unless we already did previously
      if !subscribed_to?(node)
        debug "TDEBUG - join_pubsub_node - subscribing to:  '#{node}'"
        begin
          @service.subscribe_to(node)
        rescue
          error "TDEBUG - join_pubsub_node - ERROR subscribing"
        end
        debug "Subscribed to: '#{node}'"
      else
        debug "Already subscribed to: '#{node}'"
      end
    end
    #debug "TDEBUG - LIST AFTER JOIN - #{get_all_pubsub_subscriptions}"
  end
        
  #
  # Return 'true' if a PubSub node exists
  # 
  # [Return] true/false
  #
  def node_exist?(node)
    info = nil
    begin
      info = @browser.get_info(@pubsubjid,node)  
    rescue
      #error "TDEBUG - node_exist - rescue - false"
      return false
    end
    if (info == nil)
      #debug "TDEBUG - node_exist - nil/empty - false"
      return false
    else
      #debug "TDEBUG - node_exist - exist - true" # - #{info.to_s}"
      return true
    end
  end
        
  #
  # Check if this PubSub Service Helper is already subscribed to a PubSub node
  #
  # - node = [String] name of the PubSub node 
  #
  # [Return] True/False
  #
  def subscribed_to?(node)
    listAllSubscription = get_all_pubsub_subscriptions
    listAllSubscription.each { |sub|
      #debug "TESTING - #{node} - AGAINST - #{sub.node}"
      if (sub.node == node)
        return true
      end
    }
    return false
  end
        
  #
  # Returns all subscriptions for this PubSub Service Helper
  # Note: Apparently here we also need a separate connection...
  #
  # [Return] Hash of Strings
  #
  def get_all_pubsub_subscriptions
    list = nil
    begin
      cl = Jabber::Client.new(@userJID)
      cl.connect
      cl.auth(@password)
      tmpservice = Jabber::PubSub::ServiceHelper.new(cl,@pubsubjid)
      list = tmpservice.get_subscriptions_from_all_nodes
      cl.close
    rescue Exception => ex
      debug "TDEBUG - get_all_pubsub_subscriptions - ERROR - '#{ex}'"
      return nil
    end
    return list
  end
        
end #class
