module VisyoNet
  
  class Canvas < MObject
    
    def initialize()
      @layers = Hash.new
    end
      
    def each_layer()
      @layers.each_value { |c|
        yield(c)
      }
    end
    
    # Return layer 'name'. If it doesn't exist
    # create a new one.
    # 
    # Note: A layer is really just an array
    # 
    def [](name)
      if ((l = @layers[name]) == nil)
        l = Array.new
        @layers[name] = l
      end
      l
    end
    
    def to_XML(rootName = 'initialize')
      s = "<#{rootName}>"
      each_layer { |l|
        s += '<layer>'
        l.each {|e| 
          s += e.to_XML
        }
        s += '</layer>'        
      }
      s += "</#{rootName}>"     
    end
    

  end # class Canvas
end # module Visyonet

