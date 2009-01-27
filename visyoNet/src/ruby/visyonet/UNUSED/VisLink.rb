require "visyonet/dataSource/linkModel"

module VisyoNet
  class VisLink
    @dblink = nil #DBLink reference
    @srcnode = nil #VisNode
    @destnode = nil #VisNode
    @shapes = nil #list of shapes #1st corresponds to status
    @counter = 0 #counter for shapes
    
    attr_reader :dblink, :srcNode, :destNode, :shapes
    
    def initialize(dblink, srcnode, destnode)
      @dblink = dblink
      @srcnode = srcnode
      @destnode = destnode
      
      @shapes = Array.new
      @counter = 0
      
    end
    
    def addShapes(shape)
      @shapes[@counter]=shape
      @counter = @counter + 1
    end
    
    def getnoShapes()
      return @counter
    end
    
  end
end

