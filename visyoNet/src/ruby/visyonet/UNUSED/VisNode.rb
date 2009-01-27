require "visyonet/dataSource/nodeModel"


module VisyoNet
  class VisNode
    attr_reader :position, :dbnode, :shapes
    
    
    
    
    def initialize(dbnode, position)
      @dbnode = dbnode
      @position = position
      
      @shapes = Array.new
    end
    
    def addShapes(shape)
      @shapes << shape
    end
    
    def getnoShapes()
      return @shapes.size
    end
    
  end
end
