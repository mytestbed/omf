# Copyright (c) 2014 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.

#
# This module defines a Utility which could be used to check a topology
# between distributed Resource Proxy.
#
module OmfRc::Util::Topology
  include OmfRc::ResourceProxyDSL

  # OML Measurement Point (MP)
  # This MP is reporting if a 'to' host is reachable from a 'from' host
  class OmfRc::Util::Topology::MPEdges < OML4R::MPBase
    name :edges
    param :timestamp, :type => :double # Time (s)
    param :from, :type => :string # ID/Name for this Resource Proxy
    param :to, :type => :string # Address/Name of remote host
    param :reachable, :type => :string # Is the remote host reachable?
  end

  # Check if a list of hosts from a local file are reachable from the host
  # running this Node Proxy. The input topology file must simply contain one
  # line per host, i.e. its IP address of hostname.
  # The results of this check are send to the OML server and database set
  # on the command line of this Resource Controller.
  #
  # @yieldparam [Object] from the id or name of this Node Proxy
  # @yieldparam [Object] topo_path the file with the host addresses
  #
  work :check_topology do |res,from,topo_path|
    info "Checking topology from file: '#{topo_path}'"
    File.foreach(topo_path) do |v|
      target = v.chomp
      reachable = `ping -c 1 #{target}`.include?('bytes from')
      info "Checked link to #{target}: #{reachable}"
      OmfRc::Util::Topology::MPEdges.inject(Time.now.to_i, from, target, reachable)
    end
  end
end
