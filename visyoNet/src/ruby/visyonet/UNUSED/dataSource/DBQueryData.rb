# this is the data structure that is returned on getUpdates, getAllNodes, etc

class DBQueryData
  attr_accessor :nodeQueryResult, :linkQueryResult
  
  def initialize()
    @nodeQueryResult = nil
    @linkQueryResult = nil
  end
end
