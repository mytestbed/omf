# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

# This proxy represents physical/virtual machine node, and it is the proxy which standard RC start up script initialised.
#
# Node proxy is more like a monitor proxy which monitors resource information on the node itself, it is usually created during the bootstrap process and provides an entry point for incoming FRCP messages.
#
# Resources like application, net, or wlan can be created as children of node resources by sending FRCP create messages to the node's pubsub topic.
#
# @example Creating an ethernet resource on an existing node 'node01' using communicator
#   comm.subscribe('node01') do |node|
#     node.create(:net, if_name: 'eth0')
#   end
#
# @example Creating an ethernet resource on an existing node 'node01' directly
#   node = OmfRc::ResourceFactory.create(:node)
#   node.create(:net, if_name: 'eth0')
#
# @see OmfRc::ResourceProxy::Application
# @see OmfRc::ResourceProxy::Net
# @see OmfRc::ResourceProxy::Wlan
module OmfRc::ResourceProxy::Node
  include OmfRc::ResourceProxyDSL
  # @!macro extend_dsl

  register_proxy :node

  # @!parse include OmfRc::Util::Mod
  # @!parse include OmfRc::Util::Sysfs
  utility :mod
  utility :sysfs
  utility :topology

  # @!macro group_request
  #
  # Created interfaces
  #
  # @example
  #   [{ name: 'eth0', type: 'net', uid: 'RWED2123' }]
  # @return [Array<Hash>]
  # @!macro request
  # @!method request_interface
  request :interfaces do |node|
    node.children.find_all { |v| v.type == :net || v.type == :wlan }.map do |v|
      { name: v.property.if_name, type: v.type, uid: v.uid }
    end.sort { |x, y| x[:name] <=> y[:name] }
  end

  # Created applications
  #
  # @example
  #   [{ name: 'my_app', type: 'application', uid: 'E232ER1' }]
  # @return [Array<Hash>]
  # @!macro request
  # @!method request_applications
  request :applications do |node|
    node.children.find_all { |v| v.type =~ /application/ }.map do |v|
      { name: v.hrn, type: v.type, uid: v.uid }
    end.sort { |x, y| x[:name] <=> y[:name] }
  end

  # @!endgroup

  # @!macro group_hook
  #
  # Check if device exists
  #
  # @raise [StandardError] if device not found on the node
  #
  # @!method before_create
  hook :before_create do |node, type, opts|
    if type.to_sym == :net
      net_dev = node.request_devices.find do |v|
        v[:name] == opts[:if_name]
      end
      raise StandardError, "Device '#{opts[:if_name]}' not found" if net_dev.nil?
    end
  end
  # @!endgroup

  # If a path to a topology file was given in the config file attribute
  # 'topo_file', then check the connectivity towards the resources in
  # referenced in that file. The result is sent to an OML database.
  hook :before_ready do |res|
    next if res.defaults(:topo_file).nil? || res.defaults(:topo_file).empty?
    check_topology(res.uid, res.defaults(:topo_file))    
  end
end
