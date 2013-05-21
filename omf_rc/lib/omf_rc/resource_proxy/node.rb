# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

module OmfRc::ResourceProxy::Node
  include OmfRc::ResourceProxyDSL

  register_proxy :node

  utility :mod
  utility :sysfs

  request :interfaces do |node|
    node.children.find_all { |v| v.type == :net || v.type == :wlan }.map do |v|
      { name: v.property.if_name, type: v.type, uid: v.uid }
    end.sort { |x, y| x[:name] <=> y[:name] }
  end

  request :applications do |node|
    node.children.find_all { |v| v.type =~ /application/ }.map do |v|
      { name: v.hrn, type: v.type, uid: v.uid }
    end.sort { |x, y| x[:name] <=> y[:name] }
  end

  hook :before_create do |node, type, opts|
    if type.to_sym == :net
      net_dev = node.request_devices.find do |v|
        v[:name] == opts[:if_name]
      end
      raise "Device '#{opts[:if_name]}' not found" if net_dev.nil?
    end
  end

end
