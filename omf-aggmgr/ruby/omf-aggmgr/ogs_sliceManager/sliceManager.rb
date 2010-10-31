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
# = sliceManager.rb
#
# == Description
#
# This file defines the SliceManager class.  This class implements a
# service to create and delete slices.  When a slice is created,
# several pubsub nodes are created on the XMPP server, under
# "/OMF/<slice_name>".  Resources can then be associated to a slice,
# which creates individual pubsub nodes for each resource under
# "/OMF/<slice_name>/resources/<hrn>".  Here, <hrn> is the Human
# Readable Name of the resource, and <slice_name> is the name of the
# slice.
#

require 'omf-common/servicecall'
require 'omf-aggmgr/ogs/serviceMounter'

class SliceManagerService < GridService

  # Name used to register/mount this service.
  name 'sliceManager'
  description 'Create slices and associate resources to them.'
  @@config = nil
  @@slices = Hash.new

  #
  # Create a new slice.
  #
  s_description "Create a new slice with given name on the specified pubsub domain"
  s_param :sliceName, 'sliceName', 'name of the new slice'
  s_param :pubsub_domain, 'pubsubDomain', 'the XMPP pubsub domain to create it on'
  service 'createSlice' do |sliceName, pubsub_domain|
    # Create /OMF/<sliceName> and /OMF/<sliceName>/resources on <pubsub_domain>
    MObject.debug("SliceManager", "createSlice")
    if pubsub_domain.nil?
      MObject.debug("SliceManager", "createSlice:  pubsub_domain is empty")
    end
    if sliceName.nil?
      MObject.error("SliceManager", "createSlice:  sliceName is empty")
      return false
    end
    domain = self.getPubSubDomain(pubsub_domain)
    if not domain.nil? then
      self.create_pubsub_node(domain, "/OMF/#{sliceName}")
      self.create_pubsub_node(domain, "/OMF/#{sliceName}/resources")
      # TBD:  persist a record of the slice
      @@slices[sliceName] = Array.new
    end
    true
  end

  #
  # Associate a resource to a slice.
  #
  s_description "Associate a set of resources to a slice"
  s_param :sliceName, 'sliceName', 'name of the slice'
  s_param :resources, 'resources', 'comma-separated list of resources to associate with the slice'
  s_param :pubsub_domain, 'pubsub_domain', 'the XMPP pubsub domain that hosts "sliceName"'
  service 'associateResourcesToSlice' do |sliceName, resources, pubsub_domain|
    # For each resource, create /OMF/<sliceName>/resources/<hrn>,
    # where <hrn> is the human readable name of the resource.
    MObject.debug "associateResourcesToSlice"
    if pubsub_domain.nil?
      MObject.debug("associateResourceToSlice:  pubsub_domain is empty")
    end
    if sliceName.nil?
      MObject.debug("associateResourceToSlice:  sliceName is empty")
      return false
    end
    slice_list = @@slices[sliceName] || []
    domain = self.getPubSubDomain(pubsub_domain)
    resource_list = resources.split(',')
    resource_list.each do |resource|
      self.create_pubsub_node(domain, self.resource_node(sliceName, resource))
      slice_list << resource
    end
    @@slices[sliceName] = slice_list
    true
  end

  #
  # Deassociate resource from slice
  #
  s_description "Deassociate a set of resources from a slice"
  s_param :sliceName, 'sliceName', 'name of the slice'
  s_param :resources, 'resources', 'list of resources to deassociate from the slice'
  s_param :pubsub_domain, 'pubsub_domain', 'the XMPP pubsub domain that hosts "sliceName"'
  service 'deassociateResourcesFromSlice' do |sliceName, resources, pubsub_domain|
    # For each resource, delete /OMF/<sliceName>/resources/<hrn>,
    # where <hrn> is the human readable name of the resource.
    MObject.debug "deassociateResourcesFromSlice"
    resource_list = resources.split(',')
    slice_list = @@slices[sliceName] || []
    domain = self.getPubSubDomain(pubsub_domain)
    resource_list.each do |resource|
      domain.delete_node(self.resource_node(sliceName, resource))
      slice_list.delete_if { |item| item == resource }
    end
    @@slices[sliceName] = slice_list
  end

  #
  # Delete a slice.
  #
  s_description "Delete an existing slice"
  s_param :sliceName, 'sliceName', 'name of the slice'
  s_param :pubsub_domain, 'pubsub_domain', 'the XMPP pubsub domain that hosts "sliceName"'
  service 'deleteSlice' do |sliceName, pubsub_domain|
    #
    # Request all AM's that are subscribed to nodes of the slice to leave it;
    # then delete its pubsub nodes
    #
    MObject.debug "deleteSlice"
    domain = self.getPubSubDomain(pubsub_domain)
    slice_list = @@slices[sliceName] || []
    slice_list.each do |resource|
      domain.delete_node(self.resource_node(sliceName,resource))
    end
    domain.delete_node(self.resources_node(sliceName))
    domain.delete_node(self.slice_node(sliceName))
    @@slices[sliceName] = nil
    true
  end

  #
  # Make this AM listen to messages on a particular slice
  #
  s_description "Subscribe to a slice to receive AM requests sent to it"
  s_param :sliceName, 'sliceName', 'name of the slice'
  s_param :pubsub_domain, 'pubsub_domain', 'the XMPP pubsub domain that hosts "sliceName"'
  s_param :domain, 'domain', 'the testbed domain to take resources from'
  service 'subscribeToSlice' do |sliceName, pubsub_domain, domain|
    # Cause this AM to listen on all relevant nodes for the given slice.
    domain = 'default' if domain.nil?
    xml = OMF::Services.inventory.getListOfResources(domain)
  end

  def self.configure(config)
    @@config = config
  end

  def self.getServerXMPP
    ServiceMounter.server(:xmpp)
  end

  def self.getPubSubDomain(domain)
    server = self.getServerXMPP
    dom = server.domains[domain]
    if dom.nil?
      connection = server.connection
      server.domains[domain] = OMF::XMPP::PubSub::Domain.new(connection, domain)
      dom = server.domains[domain]
    end
    dom
  end

  def self.create_pubsub_node(domain, name)
    begin
      domain.create_node(name)
    rescue Exception => ex
      # "conflict: " just means the node already exists --> no problem.
      if ex.message != "conflict: " then
        raise ex
      end
    end
  end

  def self.slice_node(slice)
    "/OMF/#{slice}"
  end

  def self.resources_node(slice)
    "#{self.slice_node(slice)}/resources"
  end

  def self.resource_node(slice, hrn)
    "#{self.resources_node(slice)}/#{hrn}"
  end

end
