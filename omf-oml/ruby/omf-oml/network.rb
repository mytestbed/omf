require 'monitor'
require 'json'
require 'set'
require 'omf-common/mobject'
require 'omf-oml'



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
    
    # Return the node named +name+. If the node doesn't exist and
    # +new_opts+ is a Hash, create a new one and return that.
    #
    def node(name, new_opts = nil)
      return name if name.kind_of? NetworkNode
      node = @name2node[name.to_sym]
      if node.nil? && !new_opts.nil?
        node = create_node(name, new_opts)
      end
      node
    end

    def links()
      @links.values
    end
    
    # Return the link named +name+. If the link doesn't exist and
    # +new_opts+ is a Hash, create a new one and return that.
    #
    def link(name, new_opts = nil)
      return name if name.kind_of? NetworkLink
      link = @name2link[name.to_sym]
      if link.nil? && !new_opts.nil?
        link = create_link(name, nil, nil, new_opts)
      end
      link
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
    
    #
    # opts
    #   :from - fromNode if +fromNode+ is nil
    #   :to - toNode if +toNode+ is nil
    #   ...  - rest of options passed on to +NetworkLink+ constructor
    #    
    def create_link(name = nil, fromNode = nil, toNode = nil, attributes = {})
      name = name.to_sym if name
      fromNode = attributes.delete(:from) unless fromNode
      toNode = attributes.delete(:to) unless toNode
            
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
    
    def node_schema(schema = null)
      if schema
        @node_schema = OmlSchema.create(schema)
        @node_schema.insert_column_at(0, :id)
        @node_schema.insert_column_at(1, :name)
      end
      @node_schema
    end
      
    def link_schema(schema = null)
      if schema
        @link_schema = OmlSchema.create(schema)
        @link_schema.insert_column_at(0, :id)
        @link_schema.insert_column_at(1, :name)
        @link_schema.insert_column_at(2, :from_id)
        @link_schema.insert_column_at(3, :to_id)
      end
      @link_schema
    end

    
    def describe
      nh = {}
      @nodes.each do |id, node| nh[id] = node.describe end
      lh = {}
      @links.each do |id, link| lh[id] = link.describe end
      {:nodes => nh, :links => lh}        
    end
    
    # Creates two tables, one capturing the link state and one for the node state.
    # Returns the two tables in a hash with keys 'nodes' and 'links'.
    #
    def to_tables(table_opts = {})
      node_table = OmlTable.new 'nodes', @node_schema, table_opts
      @nodes.each do |id, n|
        node_table.add_row @node_schema.hash_to_row(n.attributes)
      end

      link_table = OmlTable.new 'links', @link_schema, table_opts
      @links.each do |id, l|
        link_table.add_row @link_schema.hash_to_row(l.attributes)
      end
      
      on_update "__to_tables_#{node_table.object_id}" do |a|
        a.each do |e|
          if e.kind_of? NetworkNode
            node_table.add_row @node_schema.hash_to_row(e.attributes)
          else
            link_table.add_row @link_schema.hash_to_row(e.attributes)
          end
        end
      end
      {:nodes => node_table, :links => link_table}
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
  
  class NetworkElementAttributeException < Exception; end  

  
  # This class represents an abstract network element and shouldn't be used directly.
  #
  class NetworkElement < MObject

    attr_reader :name
    attr_reader :el_id
    attr_reader :attributes
    
    def initialize(name, attributes, network)
      super name
      @attributes = attributes.dup
      if @name = name
        @attributes[:name] = name
      end
      if attributes.key?(:id) || attributes.key?(:name)
        raise NetworkElementAttributeException.new("Attributes 'id' and 'name' are reserved attributes")
      end
      @el_id = @attributes[:id] = "e#{self.object_id}"
      @attributes[:name] = name || @el_id

      @network = network
    end
    
    def [](name)
      @attributes[name]
    end
    
    def []=(name, value)
      @attributes[name] = _set(value, @attributes[name])
    end
    
    # Update the element's attributes. The +attributes+ argument
    # is expected to be a hash with the key identifying the attribute
    # name and the value being the new value to set that attribute to.
    #
    def update(attributes)
      attributes.each do |name, value|
        self[name] = value
      end
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
        @attributes[:from_id] = fromNode.el_id
      end
      if toNode 
        @toNode = toNode
        @attributes[:to_id] = toNode.el_id
      end
    end
    
    def from=(node)
      @attributes[:from_id] = node.el_id if node  
      @fromNode = _set(node, @fromNode)
    end

    def to=(node)
      @attributes[:to_id] = node.el_id if node        
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
