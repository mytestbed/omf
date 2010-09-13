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
# = topology.rb
#
# == Description
#
# This file defines the Topology class that holds information about the nodes in
# the experiment.
#
require 'gratr/import.rb'
require 'gratr/dot.rb'

#
# This class describes a topology which can be used by users/experimenters to 
# describe the nodes used in their experiments. It also provides tools to 
# enable the topology requested.
#
class Topology < MObject

  @@topologies= Hash.new

  #
  # This method returns a known Topology instance.
  #
  # - uri = URI identifying the topology
  #
  # [Return] a Topology instance, or raise 'Unknown topology' if 'uri' does 
  # not identify an existing topology
  #
  def self.[](uriRaw)
    uri = uriRaw.delete("[]").chomp(".rb") # clean the uri
    topo = @@topologies[uri]
    if topo == nil
      MObject.info('Topology', "Loading topology '", uri, "'.")
      str, type = OConfig.load(uri, true)
      if type == "text/ruby"
        # 'str' has already been evaluated
        topo = @@topologies[uri]
      else
        raise "Unknown type '#{type}' for topology definition"
      end
      if topo.nil?
        raise "Unknown topology '#{uri}'."
      end
    end
    return topo
  end

  #
  # Create and Return a new topology object
  #
  # - id = URI identifying the topology (nil for anonymous topos)
  # - nodeSelector = describes the nodes in the topology
  #
  # [Return] a new Topology instance
  #
  def self.create(uri = nil, nodeSelector = nil)
    if (uri != nil &&  @@topologies[uri] != nil)
      raise "Topology '#{uri}' already defined."
    end
    return self.new(uri, nodeSelector)
  end

  #
  # This method removes a node from ALL topologies
  #
  # - node = the Node (object) to remove 
  #
  def self.removeNode(node)
    @@topologies.values.each {|t|
      t.removeNode(node)
    }
    
    if ((n = Node[node.nodeID]) != nil)
      n.notifyRemoved()
    end
  end

  def self.empty?
    @@topologies.values.each {|t|
      return false if !t.empty?
    }
    return true
  end

  def empty?
    return true if (size == 0)
    return false
  end
  
  #
  # This method is an alias for 'Topology[uri]'
  #
  # - uri = URI identifying the topology
  # 
  def self.load(topoName)
    return Topology[topoName]
  end

  #
  # Return the number of nodes in this Topology
  #
  # [Return] the number of nodes in this Topology
  #
  def size() return @nodes.size; end

  #
  # Return the node in this Topology, which has the nodeName 'label'
  #
  # - label = name of the node to return, as given by the user/experimenter 
  #           when it was added to this Topology
  #
  # [Return] the name of the resource with that label
  #
  def getNodeByLabel(label) return @mapping[label]; end

  #
  # Return the ith node in this Topology (using the order in which the 
  # nodes were added to this Topology)
  #
  # - index = the index of the node to return
  #
  # [Return] the name of the resource with that index
  #
  def getNodeByIndex(index)
    count = 0
    @nodes.each { |n|
      return n if count == index
      count = count + 1
    }
    return nil
  end
  
  #
  # Return the first node that was added to this Topology
  #
  # [Return] the name of the resource
  #
  def getFirstNode() getNodeByIndex(0); end

  #
  # Return the last node that was added to this Topology
  #
  # [Return] the name of the resource
  #
  def getLastNode() getNodeByIndex(size-1); end

  #
  # Return a random node from this Topology
  #
  # [Return] the name of the resource
  #
  def getRandomNode() r = rand(@nodes.size); getNodeByIndex(r); end

  #
  # This method returns a random node that has not been previously drawn and 
  # that will not be drawn again in subsequent calls of this method. This 
  # method returns nil if there are no more available nodes (i.e. all 
  # selected by previous calls of this method).
  #
  # [Return] the name of the resource
  #
  def getUniqueRandomNode
    if ((@randomCount < size()) && (size() > 0))
        r = getRandomNode
        while @randomSet.include?(r)  
          r = getRandomNode
        end 
        @randomSet.add(r)
        @randomCount = @randomCount + 1
        return r
    else
      warn "Cannot draw any more random resource for the Topology: "+
           "'#{@uri}'. No more available resources." 
      return nil
    end
  end

  #
  # This method removes a link between the nodes that have the nodeName 
  # 'srcName' and 'dstName' The removed link may symmetric or asymmetric.
  #
  # - srcName = name of the source node (as given by user when node was added 
  #             to the Topology)
  # - dstName = name of the destination node (as given by user when node was 
  #             added to the Topology)
  # - spec = optional, a Hash with the unique option 
  #          { :asymmetric=> true/false } default='false'
  #
  def removeLink(srcName, dstName, spec = {})
    debug "Removing link '#{srcName}' -> '#{dstName}' (specs '#{spec.to_s}')"
    linkIsAsymmetric = spec[:asymmetric] || false
    # Check if this is the first call to 'removeLink' for this topology
    # If so, then initialize a new graph
    if (@graph == nil)
      @asymmetric = linkIsAsymmetric
      initGraph()
      # Build full point to point connectivity in that graph
      @graph.vertices.each { |source|
        s = source[0]
	@graph.vertices.each { |destination|
          d = destination[0]
	  if (s != d)
            @graph.add_edge!(source ,destination)
	  end
        }
      }
    end
    # Check if this type of link is compatible with previously added links
    # i.e. a graph can only contain either symmetric or asymmetric links, 
    # not both
    if (linkIsAsymmetric != @asymmetric)
      raise "Topology:removeLink() - Cannot remove link '#{srcName}' -> "+
            "'#{dstName}'. Its specifications are incompatible with this "+
            "topology. A Topology can only contain either symmetric or "+
            "asymmetric links, not both."
    end
    @graph.remove_edge!([srcName,@mapping[srcName]],
                        [dstName,@mapping[dstName]])
  end

  #
  # This method adds a link between the nodes that have the nodeName 'srcName' 
  # and 'dstName'. The added link may have some specific parameters.
  #
  # - srcName = name of the source node (as given by user when node was added 
  #             to the Topology)
  # - dstName = name of the destination node (as given by user when node was 
  #             added to the Topology)
  # - spec = optional, a Hash with the link options, such as 
  #          { :portFilter => 5001 :delay => "54ms", :loss=>"10%", 
  #            :bw => "50kbit" :asymmetric=>true }, 
  #          by default links are symmetric  
  #
  def addLink(srcName, dstName, spec = {})
    debug "Adding link '#{srcName}' -> '#{dstName}' (specs '#{spec.to_s}')"
    linkIsAsymmetric = spec[:asymmetric] || false
    # Check if this is the first call to 'addLink' for this topology
    # If so, then initialize a new graph
    if !@graph
      @asymmetric = linkIsAsymmetric
      initGraph()
    end
    # Check if this type of link is compatible with previously added links
    # i.e. a graph can only contain either symmetric or asymmetric links, 
    # not both
    raise "Topology:addLink() - Cannot add link '#{srcName}' -> "+
          "'#{dstName}'. Its specifications are incompatible with this "+
          "topology. A Topology can only contain either symmetric or "+
          "asymmetric links, not both." if (linkIsAsymmetric != @asymmetric)
    @edges = getGraphEdges(@graph)
    source = [srcName, @mapping[srcName]]
    dstCompare = [dstName, @mapping[dstName]]
    @graph.adjacent(source).each { |dest|
      if (@graph.edge?(source,dest))
        # check if there is already a link set between source and dest
        if (dest.to_s == dstCompare.to_s)
	  # update of the link (spec ...)
	  linkSpec = @edges[source+dest].label
	  # update of a rule, which means update of a hash in a hash
	  spec.each_key{|key|
	    if(spec[key].kind_of? Hash and linkSpec[key].kind_of? Hash)
              linkSpec[key] = linkSpec[key].merge!(spec[key])
	      spec.delete(key)
            end
	  }
 	  # update of others value in the specs
 	  linkSpec.merge!(spec)
	  spec = linkSpec
	  if (spec[:values].to_s == "flush")
	    puts "flush flush"
	    spec.each_key{|key|
	      if (key != :asymmetric)
	        spec.delete(key)
	      end
	    }
          end
        end
        if (isSpecificationCompatible(spec, linkSpec) == false)
          raise "Topology:addLink() - Link '#{srcName}' to '#{dstName}' is "+
                "incompatible with previous links" 
        end
      end
    }
    # This link is OK, add it to the graph of this topology
    @graph.add_edge!([srcName,@mapping[srcName]],
                     [dstName,@mapping[dstName]],spec)
    if !linkIsAsymmetric
      @graph.add_edge!([dstName,@mapping[dstName]],
                       [srcName,@mapping[srcName]],spec)
    end
  end

  #
  # This method selects nodes from this Topology that match a given feature 
  # set
  #
  # - params = a Hash which contains the feature set to use for selection. 
  #
  # Current supported features are
  # - ':number' = number of node to select
  # - ':name' = string pattern from which to derive each node's nodeName. 
  #             Here %i% will be replaced by an increment count
  # - ':method' = how to select the nodes among those with the required 
  #               feature (only 'random' supported so far)
  # - ':features' = another Hash which contains the set of features for the 
  #                 selection
  #
  # [Return] a list of selected nodes in a Hash, where 'key' is the node name, 
  #          and 'value' is of the form [x,y]
  #
  def select(params = {})
    number = params[:number] || 1
    namePattern = params[:name] || "nodeName%i%"
    method = params[:method] || :random
    features = params[:features] || nil
    debug "select: number: #{number} - name: #{namePattern} - "+
          "method: #{method} - features: '#{features}'"
    nameList = Set.new
    for i in (1..number)
      nameList << namePattern.gsub(/%i%/, "#{i}")
    end
    if (features == nil)
      mapping = getNodeMap(nameList, self, method)
    else
      # FIXME: implement here the feature selection mechanims
      # First generate a sub Topologoy which only has nodes having ':features'
      # Then select nodes from that sub Topology, but with ':feature=>nil'
      topoWithFeature =  subTopologyWithFeatures(features)
      mapping = topoWithFeature.select(:number => number, :method => method, 
                                       :name => namePattern )
    end
    return mapping
  end

  #
  # This method saves this Topology's graph in a '.dot' file, which
  # is readable by drawing software such as graphViz. The output graph
  # file is saved with the name: 'ExperimentID-Graph.dot'
  #
  def saveGraphToFile()
    @graph.write_to_graphic_file("jpg","#{Experiment.ID}-Graph")
    info "Associated Graph saved in: #{Experiment.ID}-Graph"
  end

  #
  # This method executes a block of commands for every node in this Topology
  #
  # - &block = the block of commands to execute
  #
  def eachNode(&block) @nodes.each(&block); end

  #
  # This method calls inject over the nodes contained in this set
  #
  # - seed = optional, default=nil
  # - &block = a block of commands
  #
  def inject(seed = nil, &block) @nodes.inject(seed, &block); end

  #
  # This method adds a node to this topology. This method supports the 
  # following syntax option:
  # 'addNode("name")' will add node with the name 'name'
  # 'addNode("label", "name")' will add node with name 'name' and give it an 
  # alias 'label' 
  # 'addNode(aNode)' will add the node in the object 'aNode' of type Node.
  #
  # - *params = the definition of the node to add 
  # 
  def addNode(*params)
    vertex = nil
    resource = nil
    if (params.size == 2) 
      if params[0].kind_of?(String)
        vertex = params[0]
        resource = params[1] if params[1].kind_of?(String)  
        resource = params[1].value if params[1].kind_of?(ExperimentProperty)  
      else
        raise("Cannot add resource to topology '#{@uri}', wrong arguments "+
              "'#{params}'")
      end
    elsif (params.size == 1) 
      resource = params[0] if params[0].kind_of?(String)  
      resource = params[0].value if params[0].kind_of?(ExperimentProperty)  
      resource = params[0].name if params[0].kind_of?(Node)  
      vertex = resource
    else
      raise("Cannot add resource to topology '#{@uri}', wrong number of "+
            "arguments '#{params}'")
    end
    if vertex && resource
      addMapping(vertex, resource)
      addNodeByName(resource)
    else
      raise("Cannot add resource to topology '#{@uri}', wrong arguments "+
            "'#{params}'")
    end
  end

  def addNodeByName(name)
    begin
      # Check if EC is in 'Slave Mode' - If so, only add the node on which 
      # this EC is running as slave
      if NodeHandler.SLAVE
        if name != NodeHandler.NAME
          info "EC Slave on '#{NodeHandler.NAME}', thus ignoring node '#{name}'"
          return 
        end
      end
      @nodes.add(Node.at!(name))
    rescue ResourceException => re
      if @strict
        raise "Topology - Failed to add resource '#{name}' to topology "+
              "'#{uri}' ('strict' flag set, thus no change allowed) - #{re}"
      else
        warn "Cannot find missing resource '#{name}', ignoring it"
      end
    end
  end

  #
  # This method removes a node at coordinates x and y
  #
  # - node = the Node (object) to remove 
  #
  def removeNode(node)
    if @strict
      raise "Topology - failed to remove node '#{node}' from topology "+
            "'#{uri}'. No topology change allowed (flag 'strict' set)"
    end
    if ((n = Node[node.nodeID]) != nil)
      @nodes.delete(n) 
    end
  end

  #
  # This method adds a group of nodes to this topology.
  #
  # - nodes = the group of nodes to add. It can be either: a Hash, 
  #           which contains the mapping 'node name' to '[x,y]'. Each 
  #           element of this Hash is of the form key="node name" 
  #           and value="[x,y]" (with value as a String!). Or: an Array, 
  #           which contains the declaration of a node or a group of nodes
  # 
  def addNodes(nodes)
    # Option 1: 'nodes' is a Hash
    if nodes.kind_of?(Hash) 
      nodes.each { |k,v|
        addNode(k,eval(v))
      }
      return
    end
    # Sanity Check
    if ! nodes.kind_of?(Array)
      raise "Parameter to 'addNodes' need to be of type Array, but is "+
            "#{nodes.class.to_s}."
    end
    # Option 2: 'nodes' is an Array
    nodes.each {|n|
      addNodes(n)
    }
  end

  #
  # Go through all the nodes in this topology and build the requested links 
  # between each of them, according to the link definitions set in the 
  # topology graph
  #
  # - interface = is the interface for which the link should be set. Currently, 
  #            we use the actual interface, e.g. "ath0". This will eventually 
  #            be changed to be consistent with the device names used in the 
  #            experiment definition e.g. "w0" 
  #
  def build_links(interface)
    raise "Cannot build links for this topology '#{@uri}', no vertices "+
          "and/or edges were defined" if !@graph 
    @edges = getGraphEdges(@graph) 
    @graph.vertices.each { |source|
      srcNode = Node[source[1]]
      raise "Cannot configure link for unknown resource "+
            "'#{source[0]}'" if !srcNode
      @graph.adjacent(source).each { |destination|
        if @graph.edge?(source, destination)
	  dstNode = Node[destination[1]]  
          raise "Cannot configure link of unknown resource "+
                "'#{destination[0]}'" if !dstNode
          linkSpec = @edges[source+destination].label
          configure_link(srcNode, dstNode, interface, linkSpec)
          #if !linkSpec[:asymmetric]  
          #  configure_link(dstNode, srcNode, interface, linkSpec)
	  #end 
        end
      }
    }
  end

  # NOTE: getting the MAC, IP, etc.. info on a node is done here for now
  # we discussed doing this directly on the node itself in the future
  def configure_link(src, dst, interface, spec)
    case spec[:emulationTool].to_sym
    when nil
      error "Cannot build links for this topology '#{@uri}', no emulation "+
            "tool was set for the link between '#{src}' and '#{dst}'"
      return
    when :mackill, :ebtable, :iptable
      if spec[:state] == :down
        spec[:blockedMAC] = dst.get_MAC_address(interface)
      end
    when :netem
      spec[:targetIP] = dst.get_IP_address(interface)
      spec[:interface] = interface 
    #  
    # else... Let the resource decide if it can act on this
    end
    # NOTE: when Node's and NodeSet's deferred queues will be moved to the
    # communicator, there will be no more need to go through the Node object
    # to send this message
    src.set_link(spec)
  end


  #
  # This method will will go through all the nodes in this topology and create
  # the correct rules for our traffic shaper
  # - device = is the device to on which will be applied the rule
  #
  # Until now, the only tool available is NetEM/Tc
  # values[] = values of parameters for the action : 
  # values = [ipDst,delay,delayvar,delayCor,loss,lossCor,bw,bwBuffer,bwLimit,corrupt,duplic,portDst,portRange].  Value -1 = not set, 
  #   except for portRange, 0 
  #     
  #
  def buildTCList_OLD(device)
    raise "Cannot build Traffic Shaping list, no vertices and/or edges were "+
          "defined in this topology '#{@uri}'" if !@graph 
    #if there is a link we read the spec and create an array with all values : values = [ipDst -1,delay -1,delayvar -1,delayCor -1,loss -1,lossCor -1,bw -1,bwBuffer -1,bwLimit -1,per -1, duplication -1,portDst -1,portRange 0,portProtocol,interface]
    edges = getGraphEdges(@graph)
    @graph.vertices.each { |source|
      s   = eval(source[1])
      nodeSrc = Node[s[0],s[1]]
      @graph.adjacent(source).each { |dest|
        if (@graph.edge?(source,dest))
          d = eval(dest[1])
          spec = edges[source+dest].label
          spec.each_key{|key|
	  #if the value is a Hash, it means it is a rule. We use it
	  if (spec[key].kind_of? Hash)
	      # value to know if netem or tbf are used in the rule
	      netem = 0
	      tbf = 0
	      param = spec[key]
              debug "Link ["+s[0].to_s+","+s[1].to_s+"] -> ["+d[0].to_s+","+d[1].to_s+"] - ("+param.to_s+")"
    	      values= [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,-1,"eth0"]
	      if param[:delay]!= nil
		netem = 1
 	        values[1] = ["#{param[:delay].to_s}"]
	        if param[:delayVar] != nil
		  #delay + varation in delay
		  values[2] = ["#{param[:delayVar].to_s}"]
		  if param[:delayCor] != nil
		    #delay + variation + correlation
		    values[3] = ["#{param[:delayCor].to_s}"]
		  end
	        end
	      end
	      if param[:loss] != nil
       		netem = 1
	        values[4] =  ["#{param[:loss].to_s}"]
	        if param[:lossCor] != nil
		  #loss + loss correlation
		  values[5] = ["#{param[:lossCor].to_s}"] 
	        end
	      end
              if (param[:bw] != nil) 
                values[6] =  ["#{param[:bw].to_s}"]
		if (param[:bwBuffer] != nil)
                  values[7] = ["#{param[:bwBuffer].to_s}"]
		else
                  values[7] = "16000"
		end
		if (param[:bwLimit] != nil)
                  values[8] = ["#{param[:bwLimit].to_s}"]
		else
                  values[8] = "30000"
		end
		tbf = 1
              end
	      if param[:per] != nil
		netem = 1
 	        values[9] =  ["#{param[:per].to_s}"]
              end
	      if param[:duplication] != nil
		netem = 1
 	        values[10] =  ["#{param[:duplication].to_s}"]
              end
              nodeDst = Node[d[0],d[1]]
	      ipDst=nodeDst.ipExp?() #!!!! BROKEN!!!!
	      values[0]= ipDst
	      #Port filtered
	      if (param[:portFilter] != nil)
	        values[11] = param[:portFilter] 
                if (param[:portRange] != nil)
                  values[12]=param[:portRange]
                end
		if (param[:portProtocol] == "tcp")
		  values[13]=6
		elsif (param[:portProtocol] == "udp")
		  values[13]=17
		end

	      end
	      #netem == 0 and tbf == 0 means rule empty, or syntax error (ex : bw without buffer and limit), we don't send anything.
	      puts "value #{values}"
	      if (netem == 1 or tbf == 1)
		values[14] = device.to_s
                nodeSrc.setTrafficRules(values)
	      end
	    end
          }  
        end
      }
    }
  end



attr_reader :nodesArr

attr_accessor :strict

  private

  #
  # Topology constructor
  #
  # - uri = URI refering to this Topology
  # - nodeSelector = optional, nodes to add to this Topology (default = nil). 
  #                  This should be an Array of the for[[a, b], or [[c..d], f]]
  #
  def initialize(uri, nodeSelector)
    super(uri)
    if !uri.nil?
      if @@topologies.has_key? uri
        raise "topology with name '" + uri + "' already exists."
      end
      @@topologies[uri] = self
    end
    @strict = false
    @randomCount = 0
    @randomSet = Set.new
    @graph = nil
    @edges = nil
    @mapping = Hash.new
    @uri = uri
    @nodes = Set.new
    add(nodeSelector) if nodeSelector != nil
  end

  #
  # Add the nodes described in 'selector' in this Topology.
  #
  # - selector = descprition of nodes to add, see Constructor for more info 
  #
  def add(selector)
    if (selector.kind_of?(String))
      error "Unexpected selector declaration '#{selector}'. "+
            "Please report as bug."
    elsif selector.kind_of?(Array)
      selector.each {|node|
        addNode(node)
      }
    elsif selector.kind_of?(ExperimentProperty)
      s = selector.value
      add(s)
    else
      raise "Unrecognized node set selector type '#{selector.class}'."
    end
  end

  #
  # This method adds a mapping between a name and a set of coordinates to 
  # the graph (if any) associated with this topology
  #
  # - theCouple = an Array of 2 elements [ "nodeName", "[x,y]" ]
  #
  # NOTE: nodeName is defined by the experiment, it is different
  # from the name defined by convention for each node (e.g. n_x_y)
  #
  def addMapping(label, resource)
    @mapping[label] = resource
    @graph.add_vertex!([label, resource]) if @graph
  end

  #
  # This method creates a new GRATR graph and add the vertices currently 
  # present in the @mapping Hash (key='nodeName' and value='[x,y]')
  #
  # NOTE: nodeName is defined by the experiment, it is different
  # from the name defined by convention for each node (e.g. n_x_y)
  #
  def initGraph()
    if @asymmetric
      @graph = GRATR::DirectedGraph.new
    else
      @graph = GRATR::UndirectedGraph.new
    end
    if (@mapping.size != 0)
      @mapping.each { |k,v|
        @graph.add_vertex!([k,v])
      }
    end
  end

  #
  # This method returns true if the input specifications are compatible
  #
  # - spec1, spec2 = the two specification to compare
  #
  # [Return] true/false
  #
  def isSpecificationCompatible(spec1, spec2)
    # FIXME: add here any check/comparison between spec1 and spec2
    # return true in the meantime...
    return true
  end

  #
  # This method returns the edges associated with a given 'graph'
  #
  # - graph = the Graph instance to consider
  #
  # [Return] the set of edges for this graph
  #
  def getGraphEdges(graph)
    edges = Hash.new
    graph.edges.each { |e|
    if @asymetric
      edges[e.source+e.target] = e
    else
      edges[e.source+e.target] =  edges[e.target+e.source] = e
    end
    }
    edges
  end

  #
  # Return a sub-topology made of all the nodes in this Topology
  # which have the required 'features'
  #
  # - features = a Hash with the features required for the sub-topolgy
  #
  # [Return] a new Topology instance 
  #
  def subTopologyWithFeatures(features = {})
    # FIXME: put here some code to create a new topology with nodes from 
    # this current topology which have the desired features.
    #subT = Topology.new("someArbitraryTopoName")
    #self.eachNode {|n| 
    # #Here we check if this node 'n' has the required features
    # ...
    # #if so add this node to subT
    # subT.addNode(n.x, n.y)
    #}
    # return subT
    return self # for now...
  end

  #
  # This method associates each element of 'source' with a unique 
  # node from a given 'topo'. Each unique node is selected according to 
  # 'method' and to the specified features 'feat'
  #
  # - source = a list of element (i.e. node names) to associate
  # - topo = the Topology containing the nodes to associate 'source' with
  # - method = the method to use to perform the association 
  #            (only supported method now is ':random')
  #
  # [Return] a Hash of the form 'key'= source and 'value'= node from Topology
  #
  def getNodeMap(source, topo, method)
    mapping = Hash.new
    # Now let's map nodes
    source.each { |orig|
      if (method == :random)
          candidate = topo.getUniqueRandomNode()
      else
        # OR put here any other future selection method...
	raise("getNodemap - Unknown topology selection method '#{method}'")
      end
      mapping[orig] = "#{candidate.name}"
      addNode(candidate.name)
    }
    debug "MAP = #{mapping.to_s}"
    mapping
  end

end
