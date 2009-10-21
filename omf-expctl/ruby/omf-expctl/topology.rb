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
require 'omf-common/gratr/import.rb'
require 'omf-common/gratr/dot.rb'

#
# This class describes a topology which can be used by users/experimenters to describe 
# the nodes used in their experiments. It also provides tools to enable the 
# topology requested.
#
class Topology < MObject

  @@topologies= Hash.new

  #
  # This method returns a known Topology instance.
  #
  # - uri = URI identifying the topology
  #
  # [Return] a Topology instance, or raise 'Unknown topology' if 'uri' does not identify an
  #          existing topology
  #
  def self.[](uriRaw)
    uri = uriRaw.delete("[]") # remove leading/trailing "[" "]"
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
  # This flag switch the use of the class Node when defining a topology.
  # It should be set to 'true' when the Topology class is used with the NodeHandler,
  # and to 'false' otherwise (e.g. when used in 'tellnode' and 'statnode' tools)
  #
  # - flag = true or false
  #
  def self.useNodeClass=(flag)
    @@useNodeClass = flag
  end
  @@useNodeClass = true

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
  # - x = coordinate of the node to remove
  # - y = coordinate of the node to remove
  #
  def self.removeNode(x, y)
    @@topologies.values.each {|t|
      t.removeNode(x, y)
    }
    if ((n = Node[x, y]) != nil)
      n.notifyRemoved()
    end
  end
  
  #
  # This method returns 'true' if a given node is in at least one of 
  # the known topologies
  #
  # - x = coordinate of the node to remove
  # - y = coordinate of the node to remove
  #
  # [Return] true or false
  #
  def self.hasNode(x, y)
    response = false
    @@topologies.values.each {|t|
      if (t.hasNode(x, y))
        response = true
      end
    }
    return response
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
  # [Return] an array of the form [x,y]
  #
  def getNodeByLabel(label)
    theNode = eval(@mapping[label])
    return @nodesArr[theNode[0]][theNode[1]] 
  end

  #
  # Return the ith node in this Topology (using the order in which the nodes were
  # added to this Topology)
  #
  # - index = the index of the node to return
  #
  # [Return] an array of the form [x,y]
  #
  def getNode(index)
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
  # [Return] an array of the form [x,y]
  #
  def getFirstNode() getNode(0); end

  #
  # Return the last node that was added to this Topology
  #
  # [Return] an array of the form [x,y]
  #
  def getLastNode() getNode(size-1); end

  #
  # Return a random node from this Topology
  #
  #2Y [Return] an array of the form [x,y]
  #
  def getRandomNode() r = rand(@nodes.size); getNode(r); end

  #
  # This method returns a random node that has not been previously drawn and 
  # that will not be drawn again in subsequent calls of this method. This 
  # method returns nil if there are no more available nodes (i.e. all 
  # selected by previous calls of this method).
  #
  # [Return] an array of the form [x,y]
  #
  def getUniqueRandomNode()
    if ((@randomCount < size()) && (size() > 0))
        r = getRandomNode()
        while @randomSet.include?(r)  
          r = getRandomNode()
        end 
        @randomSet.add(r)
        @randomCount = @randomCount + 1
        return r
    else
      info "WARNING - Topology: #{@uri} - getUniqueRandomNode() called, but no more available nodes!"
      return nil
    end
  end

  #
  # This method removes a link between the nodes that have the nodeName 'srcName' and 'dstName'
  # The removed link may symmetric or asymmetric.
  #
  # - srcName = name of the source node (as given by user when node was added to the Topology)
  # - dstName = name of the destination node (as given by user when node was added to the Topology)
  # - spec = optional, a Hash with the unique option { :asymmetric=> true/false } default='false'
  #
  def removeLink(srcName, dstName, spec = {})
    debug "removeLink() #{srcName} -> #{dstName} ('#{spec.to_s}')"
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
    # i.e. a graph can only contain either symmetric or asymmetric links, not both
    if (linkIsAsymmetric != @asymmetric)
      raise "Topology:removeLink() - Link '#{srcName}' to '#{dstName}' is incompatible. A Topology an only contain either symmetric or asymmetric links, not both"
    end
    @graph.remove_edge!([srcName,@mapping[srcName]],[dstName,@mapping[dstName]])
  end

  #
  # This method adds a link between the nodes that have the nodeName 'srcName' and 'dstName'
  # The added link may have some specific parameters.
  #
  # - srcName = name of the source node (as given by user when node was added to the Topology)
  # - dstName = name of the destination node (as given by user when node was added to the Topology)
  # - spec = optional, a Hash with the link options, such as { :rate=>54, :per=>0.1, :asymmetric=>true }, by default links are symmetric
  #
  def addLink(srcName, dstName, spec = {})
    debug "addLink() #{srcName} -> #{dstName} ('#{spec.to_s}')"
    linkIsAsymmetric = spec[:asymmetric] || false
    # Check if this is the first call to 'addLink' for this topology
    # If so, then initialize a new graph
    if (@graph == nil)
      @asymmetric = linkIsAsymmetric
      initGraph()
    end
    # Check if this type of link is compatible with previously added links
    # i.e. a graph can only contain either symmetric or asymmetric links, not both
    if (linkIsAsymmetric != @asymmetric)
      raise "Topology:addLink() - Link '#{srcName}' to '#{dstName}' is incompatible. A Topology an only contain either symmetric or asymmetric links, not both"
    end
    @edges = getGraphEdges(@graph)
    source = [srcName,@mapping[srcName]]
    @graph.adjacent(source).each { |dest|
      if (@graph.edge?(source,dest))
        linkSpec = @edges[source+dest].label
        if (isSpecificationCompatible(spec, linkSpec) == false)
          raise "Topology:addLink() - Link '#{srcName}' to '#{dstName}' is incompatible with previous links" 
        end
      end
    }
    # This link is OK, add it to the graph of this topology
    @graph.add_edge!([srcName,@mapping[srcName]],[dstName,@mapping[dstName]],spec)
  end

  #
  # This method selects nodes from this Topology that match a given feature set
  #
  # - params = a Hash which contains the feature set to use for selection. Current supported features are
  # - ':number' = number of node to select
  # - ':name' = string pattern from which to derive each node's nodeName. Here %i% will be replaced by an increment count
  # - ':method' = how to select the nodes among those with the required feature (only 'random' supported so far)
  # - ':features' = another Hash which contains the set of features for the selection
  #
  # [Return] a list of selected nodes in a Hash, where 'key' is the node name, and 'value' is of the form [x,y]
  #
  def select(params = {})
    number = params[:number] || 1
    namePattern = params[:name] || "nodeName%i%"
    method = params[:method] || :random
    features = params[:features] || nil
    debug "select(): number: #{number} - name: #{namePattern} - method: #{method} - features: '#{features}'"
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
      mapping = topoWithFeature.select( :number => number, :method => method, :name => namePattern )
    end
    return mapping
  end

  #
  # This method will go through all the nodes in this topology and build/activate 
  # the correct MAC address blacklists on each of them, according to the links 
  # defined in the topology graph
  #
  # - device = is the device on which MAC blacklist should be set. Currently, we use 
  #            the actual interface, e.g. "ath0". This will eventually be changed to 
  #            be consistent with the device names used in the experiment definition
  #            e.g. "w0" 
  # - tool =  software tool to use to implement the MAC blacklist
  #
  def buildMACBlackList(device, tool)
    # NOTE: When change 'ath0' to 'w0'
    #       Nothing needs to be changed here, modifications will be in Inventory and nodeSet 

    # Sanity check
    if (@graph == nil) 
      raise "Cannot build MAC black-lists, no vertices/edges in this topology '#{@uri}'"
    end
    # First, we get all the MAC address in this topology
    allMAC = Set.new
    @graph.vertices.each { |source|
      s   = eval(source[1])
      # Query the INVENTORY gridservice for information on the source node
      mac = nil
      url = "#{OConfig[:ec_config][:inventory][:url]}/getMacAddress?x=#{s[0]}&y=#{s[1]}&ifname=#{device}&domain=#{OConfig.domain}"
      response = NodeHandler.service_call(url, "Can't get node information from INVENTORY")
      doc = REXML::Document.new(response.body)
      doc.root.elements.each("/MAC_Address/#{device}") { |e|
	mac = e.get_text.value
      }
      # There are no information on the source node's device in the INVENTORY
      # It does not make sense to continue, because we cannot physically implement
      # this topology. Thus, we terminate the experiment.
      if (mac == nil) 
        doc.root.elements.each('/MAC_Address/ERROR') { |e|
          error "Topology - #{e.get_text.value}"
	  raise "Topology - #{e.get_text.value}"
        }
      end
      MObject.info "From Inventory - x: #{s[0]} - y: #{s[1]} - mac: #{mac}"
      allMAC.add(mac)
      node = Node[s[0],s[1]]
      node.setMAC(mac)
      debug "Node: [#{s[0]},#{s[1]}] - MAC: #{mac}"
    }
    # Now, we set the blockedMAC list on each Node to allMAC
    @graph.vertices.each { |source|
      s = eval(source[1])
      node = Node[s[0],s[1]]
      node.setBlockedMACList(allMAC)
    }
    # Then, we build the MAC filtering tables on each Node by removing any allowed MAC
    @edges = getGraphEdges(@graph)
    @graph.vertices.each { |source|
      s   = eval(source[1])
      nodeSrc = Node[s[0],s[1]]
      nodeSrc.removeBlockedMAC(nodeSrc.MAC)
      @graph.adjacent(source).each { |dest|
        if (@graph.edge?(source,dest))
          d = eval(dest[1])
          spec = @edges[source+dest].label
          debug "Link ["+s[0].to_s+","+s[1].to_s+"] -> ["+d[0].to_s+","+d[1].to_s+"] - ("+spec.to_s+")"
	  # Punch a hole in the blocked MAC table of the Destination Node
	  nodeDst = Node[d[0],d[1]]
	  nodeDst.removeBlockedMAC(nodeSrc.MAC)
        end
      }
    }
    # Finally, we activate the blacklists on each node, using the 
    # 'tool' command (so far either iptable, ebtable, or mackill)
    eachNode { |n|
      n.setMACTable(tool)
    }
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
  def eachNode(&block)
    @nodes.each(&block)
  end

  #
  # This method calls inject over the nodes contained in this set
  #
  # - seed = optional, default=nil
  # - &block = a block of commands
  #
  def inject(seed = nil, &block)
    @nodes.inject(seed, &block)
  end

  #
  # Return the value of the 'strict' flag for this Topology
  # If a topology is strict an Exception is called when something
  # tries to modify it, i.e. by adding/removing nodes. For example,
  # when a node fails to start up, EC will try to remove it from 
  # this topology, which will raise an exception if 'strict' is set
  #
  # [Return] true/false
  #
  def strict?() return @strict; end

  #
  # Set the 'strict' flag for this Topology. See 'strict?' for more info
  #
  def setStrict() @strict = true; end

  #
  # Unset the 'strict' flag for this Topology. See 'strict?' for more info
  #
  def unsetStrict() @strict = false; end

  #
  # This method adds a node to this topology. This method supports the following syntax option:
  # 'addNode(x, y)' will add node at coordinate x,y.
  # 'addNode("name", [x,y])' will add node at coordinate x,y and associates 'name' to it. 
  # 'addNode(aNode)' will add the node in the object 'aNode' of type Node.
  #
  # - *params = the definition of the node to add 
  # 
  def addNode(*params)
    # - addNode(x, y)
    if (params.size() == 2) && (params[0].kind_of?(Integer)) && (params[1].kind_of?(Integer))
      x = params[0]
      y = params[1]
      addMapping(["[#{x},#{y}]","[#{x},#{y}]"])
      addNodeByCoordinate(x, y)
    # - addNode("name", [x,y])
    elsif (params.size() == 2) && (params[0].kind_of?(String)) && (params[1].kind_of?(Array))
      coord = params[1]
      addMapping([params[0],"[#{coord[0]},#{coord[1]}]"])
      addNodeByCoordinate(coord[0], coord[1])
    # - addNode(aNode)
    elsif (params.size() == 1) && (params[0].kind_of?(Node))
      node = params[0]
      addMapping(["[#{node.x},#{node.y}]","[#{node.x},#{node.y}]"])
      addNodeByCoordinate(node.x, node.y)
    else
      raise("addNode() - Syntax error, unknown argument '#{params}'")
    end
  end

  #
  # This method adds a node at coordinates x and y to this Topology
  # - x = X coordinate of added node
  # - y = Y coordinate of added node
  #
  def addNodeByCoordinate(x, y)
    begin
      # Check if EC is in 'Slave Mode' - If so, only add the node on which this EC is running as slave
      if NodeHandler.SLAVE_MODE() 
        if (x != NodeHandler.instance.slaveNodeX) || (y != NodeHandler.instance.slaveNodeY) 
          info "Slave Mode on [#{NodeHandler.instance.slaveNodeX},#{NodeHandler.instance.slaveNodeY}], thus ignoring node [#{x},#{y}]"
          return 
        end
      end
      # When Topology is not used with a NodeHandler, do not use the Node class
      n = (@@useNodeClass) ? Node.at!(x, y) :[x,y] 
      @nodes.add(n)
      @nodesArr[x][y] = n
      @nodeSetDecl = nil
    rescue ResourceException => re
      if strict?
        raise "Topology - failed to add node [#{x},#{y}] to topology #{uri} ('strict=true', no change allowed) - #{re}"
      else
        warn("Ignoring missing node '#{x}@#{y}'")
      end
    end
  end

  #
  # This method removes a node at coordinates x and y
  # - x = X coordinate of removed node
  # - y = Y coordinate of removed node
  #
  def removeNode(x, y)
    if strict?
      raise "Topology - failed to remove node [#{x},#{y}] to topology #{uri} ('strict=true', no change allowed) - #{re}"
    end
    if ((n = Node[x, y]) != nil)
      @nodes.delete(n)
      @nodesArr[x][y] = nil
      @nodeSetDecl = nil
    end
  end

  #
  # Return true if a given node is present in this topology
  # - x = X coordinate of the node
  # - y = Y coordinate of the node
  #
  # [Return] true/false
  #
  def hasNode(x, y)
    if ((n = Node[x, y]) != nil)
      if ((@nodes.include?(n)) && (@nodesArr[x][y] == n))
        return true
      else 
        return false
      end
    else
      return false  
    end
  end

  #
  # Return an array containing x,y rectangle declarations of 
  # nodes used in this topology 
  #
  # [Return] an Array of the form [[1,1]], or [[1..20, 2..3], [1..10, 10..20]]
  #
  def nodeSetDecl()
    if @nodeSetDecl.nil?
      @nodeSetDecl = calculateNodeSetDecl
    end
    @nodeSetDecl
  end

  #
  # This method adds a group of nodes to this topology.
  #
  # - nodes = the group of nodes to add. It can be either: a Hash, which contains the mapping 
  #           'node name' to '[x,y]'. Each element of this Hash is of the form key="node name" 
  #           and value="[x,y]" (with value as a String!). Or: an Array, which contains the 
  #           declaration of a node or a group of nodes
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
      raise "Parameter to 'addNodes' need to be of type Array, but is #{nodes.class.to_s}."
    end
    # Option 2: 'nodes' is an Array
    if ! nodes[0].kind_of?(Array)
      # Array should contain two ranges
      if nodes.length != 2
        raise "Expected array with 2 elements denoting x and y, but found #{nodes.join(', ')}."
      end
      x = nodes[0]
      if x.kind_of?(Integer)
        x = [x]
      elsif x.kind_of?(ExperimentProperty)
        x = [x.value]
      end
      y = nodes[1]
      if y.kind_of?(Integer)
        y = [y]
      elsif y.kind_of?(ExperimentProperty)
        y = [y.value]
      end
      if ! ((x.kind_of?(Range) || x.kind_of?(Array)) \
      && (y.kind_of?(Array) || y.kind_of?(Range)))
        raise "Expected two range declarations, but found #{nodes.join(', ')}."
      end
      x.each {|i|
        y.each {|j|
          addNode(i, j)
        }
      }
    else
      nodes.each {|n|
        addNodes(n)
      }
    end
  end

attr_reader :nodesArr

  private

  #
  # Topology constructor
  #
  # - uri = URI refering to this Topology
  # - nodeSelector = optional, nodes to add to this Topology (default = nil). This should be
  #                  an Array of the for[[a, b], or [[c..d], f]]
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
    @mapping = Hash.new
    @uri = uri
    @nodes = Set.new
    @nodesArr = ArrayMD.new
    @nodeSetDecl = nil
    add(nodeSelector) if nodeSelector != nil
  end

  #
  # Add the nodes described in 'selector' in this Topology.
  #
  # - selector = descprition of nodes to add, see Constructor for more info 
  #
  def add(selector)
    if (selector.kind_of?(String))
      error "Unexpected selector declaration '#{selector}'. Please report as bug"
    elsif selector.kind_of?(Array)
      # now lets check if the array just describes a single
      # node [x, y] a set of nodes [[a, b], [[c..d], f]]
      if (selector.length == 2 && selector[0].kind_of?(Integer) && selector[1].kind_of?(Integer))
        n = addNode(selector[0], selector[1])
      else
        addNodes(selector)
      end
      #@nodeSetDecl = selector.inspect.gsub(/ /, '') # remove spaces
    elsif selector.kind_of?(ExperimentProperty)
      s = selector.value
      add(s)
    else
      raise "Unrecognized node set selector type '#{selector.class}'."
    end
  end

  #
  # This method returns a description of the indices of occupied
  # elements in the 2D @nodeSetArr array as an array of x,y ranges.
  #
  # [Return] an Array of x,y ranges
  #
  def calculateNodeSetDecl()
    arr = @nodesArr
    result = []
    xMax = arr.length - 1
    (0 .. xMax).each {|x|
      result[x] = lres = {}
      col = arr[x].to_a
      first = nil
      y = 0
      col.inject(0) {|y, n|
        #p "#{x}:#{y} '#{n}':#{n.class}"
        if n.nil?
          if !first.nil?
            # end of sequence
            to = y - 1
            lres[first == to ? first : first .. to] = nil
            first = nil
          end
        elsif first.nil?
          # first in sequence
         # p# "first #{y}"
          first = y
        end
        y + 1
      }
      if !first.nil?
        # sequence runs to end
        to = col.length - 1
        lres[first == to ? first : first .. to] = nil
      end
    }
    # collaps hash result into a single array with [x,y], [x,y],.. format
    result2 = []
    result.inject(0) {|x, row|
      row.each_key { |range|
        xTo = (x + 1 .. xMax).detect {|x2|
          if result[x2].has_key?(range)
            result[x2].delete(range)
            false
          else
            true
          end
        }
        xTo = xTo.nil? ? xMax : xTo - 1
        result2 << [x == xTo ? x : x .. xTo, range]
      }
      x + 1
    }
    result2.inspect.gsub(/ /, '') # remove spaces
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
  def addMapping(theCouple)
    @mapping[theCouple[0]] = theCouple[1]
    if (@graph != nil)
      @graph.add_vertex!(theCouple)
    end
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
  # - method = the method to use to perform the association (only supported method now is ':random')
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
      mapping[orig] = "[#{candidate.x},#{candidate.y}]"
      addNode(candidate.x, candidate.y)
    }
    debug "MAP = #{mapping.to_s}"
    mapping
  end

end
