#
# position of a graphics object
#

module VisyoNet
  class Position < MObject
    attr_reader :x, :y
    
    def initialize(px = 0, py = 0)
      if (px == nil || py == nil)
        raise("Illegal argument")
      end
      px = px.to_i
      py = py.to_i
      debug("init: x:#{px} y:#{py}")
      @x = px
      @y = py
    end
    
    # Return a new position translated x@y to this
    # location's position
    def translate(x, y)
      debug("translate: x:#{x} y:#{y}")
      Position.new(@x + x.to_i, @y + y.to_i)
    end

    def translate!(x, y)
      @x = @x + x.to_i
      @y = @y + y.to_i
    end
  end
end

