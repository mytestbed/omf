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

require 'rubygems'
require 'dm-core'
require 'dm-migrations'

require 'omf-common/servicecall'
require 'omf-aggmgr/ogs/serviceMounter'
require 'omf-aggmgr/ogs/gridService'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, 'mysql://localhost/dmtest')

class Slice
  include DataMapper::Resource
  property :id, Serial
  property :name, String, :required => true, :unique => true
  property :pubsub_domain, String
  has n, :resources
end

class Resource
  include DataMapper::Resource
  property :id, Serial
  property :hrn, String, :required => true
  belongs_to :slice
end

class SliceManagerService < GridService

  # Name used to register/mount this service.
  name 'sliceManager'
  description 'Create slices and associate resources to them.'
  @@config = nil

  #
  # Create a new slice.
  #
  s_description "Create a new slice with given name on the specified pubsub domain"
  s_param :sliceName, 'sliceName', 'name of the new slice'
  s_param :pubsub_domain, 'pubsubDomain', 'the XMPP pubsub domain to create it on'
  service 'createSlice' do |sliceName, pubsub_domain|
    # Create /OMF/<sliceName> and /OMF/<sliceName>/resources on <pubsub_domain>
    if pubsub_domain.nil?
      MObject.error("SliceManager", "createSlice:  pubsub_domain is empty")
      raise "SliceManager.createSlice: pubsub_domain is missing"
    end
    if sliceName.nil?
      MObject.error("SliceManager", "createSlice:  sliceName is empty")
      raise "SliceManager.createSlice: sliceName is missing"
    end
    domain = self.getPubSubDomain(pubsub_domain)
    if not domain.nil? then
      self.create_pubsub_node(domain, self.slice_node(sliceName))
      self.create_pubsub_node(domain, self.resources_node(sliceName))
      # Persist a record of the slice
      begin
        existing = Slice.first(:name => sliceName)
        if existing.nil? then
          Slice.create(:name => sliceName,
                       :pubsub_domain => pubsub_domain)
        else
          MObject.debug("SliceManager", "Slice '#{sliceName}' already exists")
        end
      rescue DataObjects::SQLError => ex
        MObject.debug("SliceManager", "Exception of type #{ex.class}:  #{ex}")
        MObject.debug("SliceManager", "Code=#{ex.code}")
      end
    else
      raise "SliceManager.createSlice: couldn't find pubsub domain '#{pubsub_domain}'"
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
      MObject.debug("SliceManager", "parameter pubsub_domain is empty")
    end
    if sliceName.nil?
      MObject.debug("SliceManager", "parameter sliceName is empty")
      return false
    end
    slice = Slice.first(:name => sliceName);
    if slice.nil? then
      MObject.debug("SliceManager","Slice not found #{sliceName}")
      "Slice not found #{sliceName}"
    else
      domain = self.getPubSubDomain(pubsub_domain)
      resource_list = resources.split(',')
      resource_list.each do |resource|
        MObject.debug("SliceManager", "Associate #{resource} --> #{sliceName}")
        self.create_pubsub_node(domain, self.resource_node(sliceName, resource))
        Resource.create(:hrn => resource,
                        :slice => slice)
      end
      true
    end
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
    MObject.debug "sliceManager", "deassociateResourcesFromSlice #{sliceName}"
    resource_list = resources.split(',')
    domain = self.getPubSubDomain(pubsub_domain)
    resource_list.each do |resource|
      begin
        domain.delete_node(self.resource_node(sliceName, resource))
      rescue Exception => ex
        if ex.message == 'item-not-found: '
          MObject.debug "SliceManager", "Pubsub node #{self.resource_node(sliceName, resource)} not found; not deleting"
        else
          raise ex
        end
      end
      store = Resource.first(:hrn => resource)
      store.destroy if not store.nil?
    end
    true
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
    slice = Slice.first(:name => sliceName)
    raise "Unknown slice '#{sliceName}'" if slice.nil?
    raise "Could not find pubsub domain '#{pubsub_domain}'" if domain.nil?

    # TBD:  Tell all subscribed AM's to unsubscribe;
    # then delete the pubsub nodes
#    OMF::Services.sliceManager(:xmpp => pubsub_domain).unsubscribeFromSlice(:nonblocking => true,
#                                                                            :sliceName => sliceName)

    snode = self.slice_node(sliceName)
    rnode = self.resources_node(sliceName)
    MObject.debug "deleteSlice", "Deleting #{rnode}"
    begin
      domain.delete_node(rnode)
    rescue Exception => e
      MObject.warn "deleteSlice",  "Unable to delete slice resources node '#{rnode}': #{e}"
    end
    MObject.debug "deleteSlice", "Deleting #{snode}"
    begin
      domain.delete_node(snode)
    rescue Exception => e
      MObject.warn "deleteSlice", "Unable to delete slice node '#{snode}': #{e}"
    end
    # Remove our record of the slice; we assume all its resources are gone
    slice.destroy
    true
  end

  #
  # Make this AM listen to messages on a particular slice
  #
  s_description "Subscribe to a slice to receive AM requests sent to it"
  s_param :sliceName, 'sliceName', 'name of the slice'
  s_param :pubsub_domain, 'pubsub_domain', 'the XMPP pubsub domain that hosts "sliceName"'
  service 'subscribeToSlice' do |sliceName, pubsub_domain|
    # Cause this AM to listen on all relevant nodes for the given slice.
    # The nodes are hosted on pubsub_domain
    puts "Subscription request received"
    domain = self.getPubSubDomain(pubsub_domain)
    puts "Got p/s domain.  Trying to listen now"
    begin
      domain.listen_to_node(self.slice_node(sliceName))
    rescue Exception => e
      puts "Exceptoin:  #{e}"
    end
    puts "Listening on #{self.slice_node(sliceName)}"
    self.getServerXMPP.make_dispatcher(domain, self.slice_node(sliceName))
    # First get a list of all HRN's of all resources managed by this AM
    puts "Requesting inventory to tell us the list of our resources"
    begin
      xml = OMF::Services.inventory.getListOfResources("*") # Get ALL of our resources
    rescue Exception => e
      puts "inventory.getListOfResources() raised exception #{e}"
    end
    MObject.debug("SliceManager", "inventory.getListOfResources")
    managed_resources = xml.elements.to_a("RESOURCES/NODE").collect { |n| n.get_text }
    MObject.debug("SliceManager", "resources:")
    MObject.debug("SliceManager", managed_resources.join(', '))

    # Now get a list of resources associated to the slice
    puts "Attempting to get list of slice resources"
    begin
      resources = OMF::Services.sliceManager(:xmpp => pubsub_domain).getResourceList(:sliceID => sliceName,
                                                                                     :sliceName => sliceName,
                                                                                     :pubsub_domain => pubsub_domain)
    rescue Exception => e
      puts "sliceManager.getResourceList() raised exception #{e}"
    end

    puts "Building display list for slice resources"
    slice = Slice.first(:name => sliceName)
    resources = Resource.all(:slice => [ :name => sliceName ])
    slice_resources = resources.collect { |r| r.hrn }
    MObject.debug("SliceManager", slice_resources.join(', '))
    true
  end

  s_description "Unsubscribe from a slice"
  s_param :sliceName, 'sliceName', 'name of the slice'
  s_param :pubsub_domain, 'pubsub_domain', 'the XMPP pubsub domain that hosts "sliceName"'
  service 'unsubscribeFromSlice' do |sliceName|
    slice = Slice.first(:name => sliceName)
    domain = self.getPubSubDomain(slice.pubsub_domain)
  end

  #
  # Get a list of resources for this slice
  #   Assumption:  the slice is hosted on this AM
  #
  s_description "List the resources currently associated to a slice"
  s_param :sliceName, 'sliceName', 'name of the slice'
  s_param :pubsub_domain, 'pubsub_domain', 'the XMPP pubsub domain that hosts "sliceName"'
  service 'getResourceList' do |sliceName, pubsub_domain|
    slice = Slice.first(:name => sliceName)
    result = nil
    if slice.nil? then
      result = "Slice does not exist"
    else
      MObject.debug("SliceManager", "Slice exists: #{sliceName}")
      resources = Resource.all(:slice => [ :name => sliceName ])

      list = resources.collect { |r| r.hrn }.join(',')
      result = REXML::Element.new("resources").add_text(list)
    end
    result
  end

  def self.configure(config)
    @@config = config
    DataMapper.finalize
    DataMapper.auto_upgrade!
  end

  def self.getServerXMPP
    ServiceMounter.server(:xmpp)
  end

  #
  # Given a (string) name of an XMPP pubsub domain, return an
  # OMF::XMPP::PubSub::Domain object for it.  If none currently
  # exists, create it.  The domain object is registered in the AM's
  # central XMPP server manager.  See server.rb.
  #
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

  #
  # Create a new pubsub node on the given domain.  domain should be an
  # OMF::XMPP::PubSub::Domain object
  #
  # If the node did not already exist it is created and :ok is returned.
  # If the node does already exist then :exists is returned.
  #
  def self.create_pubsub_node(domain, name)
    result = nil
    begin
      domain.create_node(name)
      result = :ok
    rescue Exception => ex
      # "conflict: " just means the node already exists --> no problem.
      if ex.message == "conflict: " then
        result = :exists
      else
        raise ex
      end
    end
    result
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
