require 'monitor'
require 'json'
require 'set'
require 'omf-common/mobject'
require 'oml'



module OMF::OML
  
  class OmlNetworkAlreadyExistException < Exception; end  
  class OmlNodeAlreadyExistException < Exception; end
  class OmlLinkAlreadyExistException < Exception; end  

  class UnknownOmlNodeException < Exception; end
  
  class SameNameOnUpdateException < Exception; end  
          
  # This class represents a network consisting of nodes and links with their respective
  # attributes.
  #
  class OmlNetwork < MObject
    include MonitorMixin
    
    @@name2network = {}
    
    # Return a named network
    #
    def self.[](name)
      @@name2network[name]
    end
    
    attr_reader :name

    # 
    # name - Name of table
    # opts -
    #
    def initialize(name = nil, attributes = {})
      super name
      @name = name
      @attributes = attributes
      @nodes = {}
      @name2node = {}
      @links = {}   
      @name2link = {}
      @epoch = 0 # increment whenever an element is being updated
      @updateListeners = {}
      if name
        synchronize do
          if @@name2network[name]
            raise OmlNetworkAlreadyExistException.new(name)
          end
          @@name2network[name] = self
        end
      end      
    end
    
    def nodes()
      @nodes.values
    end
    
    def node(name)
      return name if name.kind_of? NetworkNode
      @name2node[name.to_sym]
    end

    def links()
      @links.values
    end
    
    def link(name)
      @name2link[name.to_sym]
    end

  
    # Register a callback to be called every time network elements change
    # The callback is provided with an arrach of changed elements.
    #
    def on_update(name = :_, &callback)
      if (callback)
        if @updateListeners[name]
          throw SameNameOnUpdateException.new(name)
        end
        @updateListeners[name] = callback
      else
        @updateListeners.delete(name)
      end
    end
    
    # NOTE: May need a monitor if used in multi-threaded environments
    #
    def create_node(name = nil, attributes = {})
      name = name.to_sym if name
      synchronize do
        if name && @name2node[name]
          raise OmlNodeAlreadyExistException.new(name)
        end
        node = NetworkNode.new(name, attributes, self)
        @nodes[node.el_id] = node
        @name2node[name] = node if name
        node
      end
    end
    
    def create_link(name = nil, fromNode = nil, toNode = nil, attributes = {})
      name = name.to_sym if name
      synchronize do
        if name && @name2link[name]
          raise OmlLinkAlreadyExistException.new(name)
        end
        if fromNode
          fromNode = node(fromNode) || (raise UnknownOmlNodeException.new(fromNode))
        end
        if toNode
          toNode = node(toNode) || (raise UnknownOmlNodeException.new(toNode))
        end
        link = NetworkLink.new(name, fromNode, toNode, attributes, self)
        @links[link.el_id] = link
        @name2link[name] = link if name
        link
      end
    end
    
    # To have the update listeners only called once when multiple elements are changed at once, perform the
    # changes within a +transaction+ block. The listeners are then called once with an array containing
    # all updated elements.
    # 
    def transaction(&block)
      updated = UpdateSet.new
      synchronize do
        @updated = updated

        @in_transaction = true
        block.call
        @in_transaction = true        
      end
      unless updated.empty?
        @updateListeners.values.each do |l|
          l.call(updated)
        end
      end
    end
    
    def describe
      nh = {}
      @nodes.each do |id, node| nh[id] = node.describe end
      lh = {}
      @links.each do |id, link| lh[id] = link.describe end
      {:nodes => nh, :links => lh}        
    end
    
    def to_json
      describe.to_json
    end
    
    def updated(element)
      synchronize do
        if @in_transaction
          @updated << element
          return        
        end
      end
      uset = UpdateSet.new
      uset << element
      @updateListeners.each do |l|
        l.call(uset)
      end
    end

  end # OMLNetwork
  
  # This class represents an abstract network element and shouldn't be used directly.
  #
  class NetworkElement < MObject

    attr_reader :name
    attr_reader :el_id
    attr_reader :attributes
    
    def initialize(name, attributes, network)
      super name
      id = "e#{self.object_id}"
      @attributes = attributes.dup
      if @name = name
        @attributes[:name] = name
      end
      #@el_id = @attributes[:id] = id
      @el_id = id
      @network = network
    end
    
    def [](name)
      @attributes[name]
    end
    
    def []=(name, value)
      @attributes[name] = _set(value, @attributes[name])
    end
    
    # Return the current state of the network element as hash
    #
    def describe
      @attributes        
    end
    
    def node?
      false
    end
    
    def link?
      false
    end
    
    protected
    
    def _set(value, old_value)
      if value != old_value
        @network.updated(self)
      end
      value
    end
    
  end # NetworkElement 
  
  # This class represents a network node. Should NOT be created directly, but only through
  # +OmlNetwork#create_node+ method
  #
  class NetworkNode < NetworkElement
    
    def initialize(name, attributes, network)
      super
    end
    
    def node?
      true
    end
  end # NetworkNode  

  # This class represents a network link between two nodes. 
  # Should NOT be created directly, but only through
  # +OmlNetwork#create_node+ method
  #
  class NetworkLink < NetworkElement
    attr_reader :from  # node
    attr_reader :to    # node
    
    def initialize(name, fromNode, toNode, attributes, network)
      super name, attributes, network
      if fromNode
        @fromNode = fromNode
        #puts ">>>> NODE: #{fromNode.inspect}"
        @attributes[:from] = fromNode.el_id
      end
      if toNode 
        @toNode = toNode
        @attributes[:to] = toNode.el_id
      end
    end
    
    def from=(node)
      @attributes[:from] = node.el_id if node  
      @fromNode = _set(node, @fromNode)
    end

    def to=(node)
      @attributes[:to] = node.el_id if node        
      @toNode = _set(node, @toNode)
    end
    
    def link?
      true
    end
  end # NetworkLink  

  # This set may hold a set of nodes and links which have been
  # updated during a transaction. It supports the +describe+
  # function which returns a domain-specific combine of all the
  # included network elements.
  #
  class UpdateSet < Set
    def describe()
      nh = {}
      lh = {}
      
      self.each do |el| 
        d = el.describe
        if el.kind_of? NetworkNode
          nh[el.el_id] = d
        else
          lh[el.el_id] = d
        end 
      end
      {:nodes => nh, :links => lh}        
    end
  end
end

if $0 == __FILE__
  require 'json'
  include OMF::Common::OML
  
  nw = OmlNetwork.new
  
  cnt = 3
  cnt.times do |i| 
    nw.create_node "n#{i}", :x => i
  end
  cnt.times do |i| 
    nw.create_link "l#{i}", "n#{i}", "n#{(i + 1) % cnt}", :y => i
  end
  
  puts nw.describe.to_json
  
  nw.on_update do |els|
    puts "UPDATED: #{els}"
  end
  nw.nodes.first[:x] = 20
  
  nw.transaction do 
    nw.nodes.first[:x] = 30
    nw.links.first[:y] = 20    
  end
end 
