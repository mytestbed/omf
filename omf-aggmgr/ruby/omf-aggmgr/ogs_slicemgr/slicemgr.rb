#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
# Copyright (c) 2004-2010 - WINLAB, Rutgers University, USA
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
# slicemgr.rb: Provide an XML-RPC interface to the PubSub server to allow
# external entities to create PubSub groups; specifically, to create the
# structure required for new slices.
#

require 'xmlrpc/server'
require 'omf-common/omfXMPPServices'
require 'xmpp4r'
require 'xmpp4r/pubsub'
require 'xmpp4r/pubsub/helper/nodebrowser'
include Jabber

ERR_INVALID_SLICE_NAME = 1

DOMAIN = '/OMF'
RESOURCES = 'resources'

class SlicemgrService < LegacyGridService

  @@config = nil
  @@pubsub = nil
  @@browser = nil
  @@dryrun_nodes = nil

  name 'slicemgr'
  info 'XML-RPC interface to the PubSub server for slice creation'

  s_info 'Create PubSub nodes for a new slice.'
  service 'createSlice' do |slice|
    if check_slice_name(slice) then
      sliceid = slice_pubsub_id(slice)
      resources_node = resources_node_pubsub_id(slice)
      MObject.debug(serviceName, "Adding a slice named '#{sliceid}'")
      create_pubsub_node("#{sliceid}")
      create_pubsub_node("#{resources_node}")
      {
        :result => "OK",
        :name => sliceid
      }
    end
  end

  s_info 'Create PubSub node for a new resource in a given slice.'
  service 'addResource' do |slice, resource|
    if check_slice_name(slice) then
      sliceid = slice_pubsub_id(slice)
      resources_node = resources_node_pubsub_id(slice)
      resourceid = resource_pubsub_id(slice, resource)
      MObject.debug(serviceName, "Create a new node #{resource} under #{resources_node}")
      create_pubsub_node(resourceid);
      {
        :result => "OK",
        :slice => sliceid,
        :resource => resourceid
      }
    end
  end

  s_info 'Delete the PubSub node for a resource in a slice.'
  service 'removeResource' do |slice, resource|
    if check_slice_name(slice) then
      sliceid = slice_pubsub_id(slice)
      resourceid = resource_pubsub_id(slice, resource)
      MObject.debug(serviceName, "Remove node #{resource} from slice #{slice}")
      remove_pubsub_node(resourceid)
      {
        :result => "OK",
        :slice => sliceid,
        :resource => resourceid
      }
    end
  end

  s_info 'Delete the PubSub node for a given slice.'
  service 'deleteSlice' do |slice|
    if check_slice_name(slice) then
      sliceid = slice_pubsub_id(slice)
      resources_node = resources_node_pubsub_id(slice)
      slice_resources = get_resources_for_slice(slice)
      slice_resources.each do |resource|
        MObject.debug(serviceName, "Removing resource #{resource} (belongs to #{sliceid})")
        remove_pubsub_node(resource)
      end
      MObject.debug(serviceName, "Remove slice #{sliceid}")
      remove_pubsub_node(sliceid)
      remove_pubsub_node(resources_node)
      result = { :result => "OK", :slice => sliceid }
      if not slice_resources.empty? then
        result[:resources] = slice_resources
      end
      result
    end
  end

  def self.mount(server, prefix = "/#{self.serviceName}")
    MObject.debug(serviceName, "Registering XML-RPC methods")
    servlet = XMLRPC::WEBrickServlet.new
    services = @@services[self] || {}
    services.each do |name, params|
      methodName = "#{serviceName}.#{name}"
      MObject.debug(serviceName, "Registering XML-RPC method '#{methodName}'")
      servlet.add_handler(methodName, &params[:proc])
    end
    server.mount(prefix, servlet)
  end

  def self.configure(config)
    @@config = config
    ['server', 'username', 'password'].each do |cfg|
      error("Missing mandatory configuration item #{cfg}") if @@config[cfg] == nil
    end

    if @@config['dry-run'] == nil or ['no', 'false'].include?(@@config['dry-run']) then
      @@pubsub = OmfPubSubService.new(@@config['username'].to_s,
                                      @@config['password'].to_s,
                                      @@config['server'])
      client = Client.new(JID::new("#{@@config['username']}@#{@@config['server']}"))
      client.connect
      client.auth("#{@@config['password']}")
      client.send(Presence.new)
      @@browser = PubSub::NodeBrowser.new(client)
      @@pubsubjid = "pubsub.#{@@config['server']}"
    else
      MObject.info(serviceName, "This is a dry run:  no PubSub nodes will be added/removed on the XMPP server.")
    end
  end

  def self.slice_pubsub_id(slice_name)
    "#{DOMAIN}/#{slice_name}"
  end

  def self.resources_node_pubsub_id(slice_name)
    "#{slice_pubsub_id(slice_name)}/#{RESOURCES}"
  end

  def self.resource_pubsub_id(slice_name, resource_name)
    "#{resources_node_pubsub_id(slice_name)}/#{resource_name}"
  end

  def self.list_all_pubsub_nodes
    if @@browser == nil then
      @@dryrun_nodes.dup
    else
      @@browser.nodes(@@pubsubjid)
    end
  end

  def self.create_pubsub_node(name)
    if @@pubsub == nil then
      @@dryrun_nodes = @@dryrun_nodes || []
      @@dryrun_nodes += [name]
    else
      @@pubsub.create_pubsub_node(name)
    end
  end

  def self.remove_pubsub_node(name)
    if @@pubsub == nil then
      @@dryrun_nodes = @@dryrun_nodes || []
      @@dryrun_nodes.delete(name)
    else
      @@pubsub.remove_pubsub_node(name)
    end
  end

  def self.check_slice_name(slice)
      if slice.upcase == 'SYSTEM' then
      raise XMLRPC::FaultException.new(ERR_INVALID_SLICE_NAME,
                                       "'system' is reserved and cannot be used as a slice name.")
      else
        true
      end
  end

  def self.get_resources_for_slice(slice)
    slice_resources_prefix = "#{resources_node_pubsub_id(slice)}/"
    prefix_length = slice_resources_prefix.length
    all = list_all_pubsub_nodes
    all.delete_if do |node|
      prefix = node[0..prefix_length-1]
      prefix != slice_resources_prefix
    end
    all
  end
end
