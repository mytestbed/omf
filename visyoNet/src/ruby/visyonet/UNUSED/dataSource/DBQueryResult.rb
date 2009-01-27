# query result class

class DBQueryResult
  attr_accessor :resultSet
  
  def initialize()
    @resultSet = nil
  end
  
  def free
    if(@resultSet != nil)
      @resultSet.free
      @resultSet = nil
    end
  end
end


