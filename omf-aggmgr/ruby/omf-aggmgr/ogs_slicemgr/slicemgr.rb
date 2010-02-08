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
require 'omf-common/omfPubSubService'
require 'xmpp4r'
require 'xmpp4r/pubsub'
require 'xmpp4r/pubsub/helper/nodebrowser'
include Jabber

ERR_INVALID_SLICE_NAME = 1

RESOURCES = 'resources'

class SlicemgrService < GridService

  @@config = nil
  @@pubsub = nil
  @@browser = nil

  name 'slicemgr'
  info 'XML-RPC interface to the PubSub server for slice creation'

  s_info 'Create PubSub groups for a new slice.'
  service 'createSlice' do |slice|
    if self.check_slice_name(slice) then
      sliceid = self.slice_id(slice)
      resourcesid = self.resources_id(slice)
      MObject.debug(serviceName, "Adding a slice named '#{sliceid}'")
      @@pubsub.create_pubsub_node("#{sliceid}")
      @@pubsub.create_pubsub_node("#{resourcesid}")
      {
        :result => "OK",
        :name => sliceid
      }
    end
  end

  s_info 'Create PubSub groups for a new node in a given slice.'
  service 'createNode' do |slice, node|
    if self.check_slice_name(slice) then
      sliceid = self.slice_id(slice)
      resourcesid = self.resources_id(slice)
      nodeid = self.node_id(slice, node)
      MObject.debug(serviceName, "Create a new node #{node} under #{resourcesid}")
      @@pubsub.create_pubsub_node(nodeid);
      {
        :result => "OK",
        :slice => sliceid,
        :node => nodeid
      }
    end
  end

  s_info 'Remove a PubSub group for a node in a slice.'
  service 'removeNode' do |slice, node|
    if self.check_slice_name(slice) then
      sliceid = self.slice_id(slice)
      nodeid = self.node_id(slice, node)
      MObject.debug(serviceName, "Remove node #{node} from slice #{slice}")
      @@pubsub.remove_pubsub_node(nodeid)
      {
        :result => "OK",
        :slice => sliceid,
        :node => nodeid
      }
    end
  end

  s_info 'Remove the PubSub group for a given slice.'
  service 'removeSlice' do |slice|
    if self.check_slice_name(slice) then
      sliceid = self.slice_id(slice)
      resourcesid = self.resources_id(slice)
      slice_nodes = self.get_nodes_for_slice(slice)
      slice_nodes.each do |node|
        MObject.debug(serviceName, "Removing node #{node} (belongs to #{sliceid})")
        @@pubsub.remove_pubsub_node(node)
      end
      MObject.debug(serviceName, "Remove slice #{sliceid}")
      @@pubsub.remove_pubsub_node(sliceid)
      @@pubsub.remove_pubsub_node(resourcesid)
      result = { :result => "OK", :slice => sliceid }
      if not slice_nodes.empty? then
        result[:nodes] = slice_nodes
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
      error("Missing configuration item #{cfg}") if @@config[cfg] == nil
    end
    @@pubsub = OmfPubSubService.new(@@config['username'].to_s,
                                    @@config['password'].to_s,
                                    @@config['server'])
    client = Client.new(JID::new("#{@@config['username']}@#{@@config['server']}"))
    client.connect
    client.auth("#{@@config['password']}")
    client.send(Presence.new)
    @@browser = PubSub::NodeBrowser.new(client)
    @@pubsubjid = "pubsub.#{@@config['server']}"
  end

  def self.slice_id(slice_name)
    "OMF/#{slice_name}"
  end

  def self.resources_id(slice_name)
    "#{self.slice_id(slice_name)}/#{RESOURCES}"
  end

  def self.node_id(slice_name, node_name)
    "#{self.resources_id(slice_name)}/#{node_name}"
  end

  def self.list_all_nodes
    @@browser.nodes(@@pubsubjid)
  end

  def self.check_slice_name(slice)
      if slice.upcase == 'SYSTEM' then
      raise XMLRPC::FaultException.new(ERR_INVALID_SLICE_NAME,
                                       "'system' is reserved and cannot be used as a slice name.")
      else
        true
      end
  end

  def self.get_nodes_for_slice(slice)
    slice_resources_prefix = "#{self.resources_id(slice)}/"
    prefix_length = slice_resources_prefix.length
    all = self.list_all_nodes
    all.delete_if do |node|
      prefix = node[0..prefix_length-1]
      prefix != slice_resources_prefix
    end
    all
  end
end
