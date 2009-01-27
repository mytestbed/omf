
module VisyoNet
  
  class VisSession
    
    # Return the session instance encoded
    # in 'req'. Create a new one if there
    # is no one found.
    # 
    def self.instance(req, context)
      if (@inst == nil)
        @inst = VisSession.new(context)
      end
      @inst
    end
    
    attr_writer :dataSource, :visMapping
    
    # Read session attribute
    def [](name)
      @attr[name]
    end
    
    # Set session attribute
    def []=(name, value)
      @attr[name] = value
    end
    
    def getDataModel()
      @dataSource.getModel(self)
    end
    
    # Convert the data model into a visualization
    # Return a hash of visualization objects
    # 
    def convert(dataModel)
      @visMapping.convert(dataModel, self)
    end
    
    # Return the visual model associated with 
    # this session.
    #
    def getVisModel()
      dm = getDataModel()
      vm = convert(dm)
      vm
    end
    
    def initialize(context)
      @attr = Hash.new
      @attr[:realTime] = @attr[:realTimeSource] = context.isRealTimeSource
      @attr[:interval] = context.defInterval

      @attr[:startTime] = 0
      @attr[:maxTime] = -1
      @attr[:minTime] = -1
      
      @dataSource = context.defDataSource
      @dataSource.initSession(self, context)
      @visMapping = context.defVisMapping
      @visMapping.initSession(self, context)      
    end 
  end
end
