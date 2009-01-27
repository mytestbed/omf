
#include the DBDatamodel
#require "visyonet/dbDataModel/DBDataModel"
#require "visyonet/dbDataModel/Position"


#include the VisModel Objects
#require "visyonet/visModel/canvas"
#require "visyonet/visModel/Color"
#require "visyonet/visModel/Shape"
#require "visyonet/visModel/Shape2D"
#require "visyonet/visModel/Shape3D"
#require "visyonet/visModel/Position"

module VisyoNet
  
  #Timing for updates is implemented using the Webbrick Interface
  class VisMapping < ::MObject
  
    DEF_WIDTH = '4in'
    DEF_HEIGHT = '10cm'
    DEF_BOUNDING_BOX = '0 0 100 100'
    
    def self.processConfig(root)
      VisMapping.new(root)
    end
    
    def self.defMappingGroup(name, x = 0, y = 0, &block)
      inst = VisMapping.new(nil, x, y)
      @@mappings[name] = inst      
      if (block != nil)
        yield(inst)
      end
    end
    
    def self.[](name)
      @@mappings[name]
    end
    
    @@mappings = Hash.new
    
    attr_accessor :width, :height, :boundingBox, :transform
    
    def initialize(rootEl = nil, x = 0, y = 0)
      @procs = Hash.new
      if rootEl != nil
        if (rootEl.name != 'VisMapping')
          raise "Doesn't appear to be a proper VisMapping config - starts with '#{root.name}'"
        end
        if ((id = rootEl.attributes['id']) == nil)
          raise "Missing 'id' attribute in 'DataSource' tag"      
        end
        @description = rootEl.attributes['description']
        if (orig = rootEl.elements['origin'])
          x = (orig.attributes['x'] || 0).to_f
          y = (orig.attributes['y'] || 0).to_f          
        end
        @procs['node'] = toProc(rootEl, true)
        @procs['link'] = toProc(rootEl, false)
        
        if (id == nil)
          raise "Missing 'id' for VisMapping."
        end
        info("VisMapping '#{id}'")
        @@mappings[id] = self
      end
      #@anchor = VisyoNet::Position.new(x, y)
    end
    
    def defMapping(name, &block)
      @procs[name] = block
    end
    
    def toProc(root, isNode)
      elName = isNode ? 'node' : 'link'
      if ((parent = root.elements[elName]) == nil)
        raise "Missing '#{elName}' definition for VisMapping"
      end
      s = ""
      parent.children.each { |el|
        s += el.to_s
      }
      if (isNode)
        return Proc.new {|canvas, anchor, node| eval s}
      else
        return Proc.new {|canvas, anchor, link| eval s}
      end
    end
    
    def initSession(session, context)
      # default is to do nothing
    end    
    
    # Convert the nodes and links into a visualization
    # Return a hash of visualization objects
    # 
    def convert(dataModel, session)
#      canvas = Canvas.new
#      anchor = Position.new()
      canvas = SVG.new(@width || DEF_WIDTH, @height || DEF_HEIGHT,
        @boundingBox || DEF_BOUNDING_BOX)
      inner = SVG::Group.new()
      (inner.transform = @transform) if @transform != nil
      canvas << inner
      anchor = nil
      
      nodes = dataModel['nodes']
      links = dataModel['links']
      if (nodes != nil && (nproc = @procs['node']) != nil)
        nodes.each_value { |n|
          nproc.call(inner, anchor, n)
        }
      end
      if (links != nil && (lproc = @procs['link']) != nil)
        links.each_value { |l|
          lproc.call(inner, anchor, l)
        }
      end
      canvas
    end
  end #end of the class
end # module