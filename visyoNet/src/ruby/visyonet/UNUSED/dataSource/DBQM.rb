require "util/mysql"

#timer remove it when not necessary
#require "../VisServer/Timer"

class DBQM  
  def initialize(cfg = {}) 
    # connection parameters
    setConnectionParameter(cfg[:host], cfg[:username], 
      cfg[:passwd], cfg[:database])
    
    # node and link queries
    @nodeQuery = ""
    @allNodesQuery = ""
    @linkQuery = ""
    # expriment time span
    @expTimeSpanQuery = ""
    
    #db connection handle
    @dbh = nil
    @firstUpdateRequest = true
    
    @avgInterval = 1
    @crtTime = 0
    @dbh = nil
    @minTime = 0
    @maxTime = 0
    
    @dbLive = false
  end
  
  
  def setConnectionParameters(host, username, passwd, database) 
    setConnectionParameters("localhost", "", "", "")
    @dbHost = host || 'localhost'
    @dbUsername = username
    @dbPasswd = passwd || ''
    @dbDatabase = database 
    # connect to the database server
    if (@dbUsername != nil && @dbDatabase != nil) 
      @dbh = Mysql.real_connect(@dbHost, @dbUsername, @dbPasswd, @dbDatabase)
    else
      @dbh = nil
    end
  end
  
  def setDbLive(flag)
    @dbLive = flag
  end
  
  def getUpdates()
    #puts "DBQM: getUpdates called with " + ConfigurationManager.instance.GetDBIsLive().to_s
    
    ret = DBQueryData.new()
    # ConfigurationManager.instance.GetDBIsLive() == false
    if (!@dbLive)
      if(@firstUpdateRequest) 
        #puts "first update request"
        # this is the first update request - prepare the timestamp counter
        PrepareForUpdateRequests()
        @firstUpdateRequest = false
      end
      
      ret = DBQueryData.new()
      ret.nodeQueryResult = runNodeQuery()
      ret.linkQueryResult = runLinkQuery()
      
      # before returning, increment the current time with avgInterval
      #puts "Current time: " + @crtTime.to_s
      if ((@crtTime + @avgInterval) > @maxTime)
        #puts "crtTime set to max"
        @crtTime = @maxTime
      else  
        @crtTime = @crtTime + @avgInterval
      end
      #puts "Next time: " + @crtTime.to_s
      
      
    else 
      #puts "getting live exp id span..."
      LiveUpdateRequests()
      #puts "got it."
      @avgInterval = @maxTime - @minTime
      
      #puts "running queries..."
      ret.nodeQueryResult = runNodeQuery()
      ret.linkQueryResult = runLinkQuery()
      
      #puts "Current id interval: " + @crtTime.to_s + " ... " + (@crtTime + @avgInterval).to_s
      
    end
    
    #Nicu please fix this; if there are no nodes 
    #there can be no links; it is ok.
    if (ret.nodeQueryResult == nil)
      return nil
    end
    
    #puts "returning " + ret.to_s
    return ret
    
  end
  
  # PrepareForUpdateRequests
  # this function is called before the first runNodeQuery or runLinkQuery call is issued
  def PrepareForUpdateRequests()
    @minTime = 0
    @maxTime = 0
    @crtTime = 0
    if(@expTimeSpanQuery != "") 
      result = runQuery(@expTimeSpanQuery)
      if(result != nil)
        # the result should have a single row and 2 columns: minTime and maxTime
        if((result.resultSet.num_rows() == 0) || (result.resultSet.num_fields() < 2))
          puts "DBQuerymanager::PrepareForUpdateRequests: experiment time span query returned improper result"
          result.free()
          return
        end
        row = result.resultSet.fetch_row()
        @minTime = row[0].to_i
        @maxTime = row[1].to_i
        #puts "crtTime set to min"
        @crtTime = @minTime
      end
      result.free()
    end
    puts "Experiment time span: " + @minTime.to_s + " to " + @maxTime.to_s
    return
  end
  
  
  # LiveUpdateRequests
  # this function is called before the first runNodeQuery or runLinkQuery call is issued
  def LiveUpdateRequests()
    @minTime = @maxTime + 1
    @maxTime = 0
    @crtTime = @minTime
    if(@expTimeSpanQuery != "") 
      puts @expTimeSpanQuery
      result = runQuery(@expTimeSpanQuery)
      puts "result: " + result.to_s
      if(result != nil)
        # the result should have a single row and 2 columns: minTime and maxTime
        if((result.resultSet.num_rows() == 0) || (result.resultSet.num_fields() < 2))
          puts "DBQuerymanager::LiveUpdateRequests: experiment time span query returned improper result"
          result.free()
          return
        end
        row = result.resultSet.fetch_row()
        # @minTime = row[0].to_i
        @maxTime = row[1].to_i
        #puts "crtTime set to min"
      end
      result.free()
    end
    puts "Live Experiment id span: " + @minTime.to_s + " to " + @maxTime.to_s
    return
  end
  
  
  
  
  
  
  def getAllNodes()
    return runAllNodesQuery()
  end  
  
  
  def setNodeQuery(queryText)
    @nodeQuery = queryText
  end
  
  def setAllNodesQuery(queryText)
    @allNodesQuery = queryText
  end
  
  def setLinkQuery(queryText)
    @linkQuery = queryText
  end
  
  def setExperimentTimeSpanQuery(queryText)
    @expTimeSpanQuery = queryText
  end
  
  def runQuery(queryString) 
    #if dbh is nil there is a problem
    if(@dbh == nil) 
      return nil
    end
    
    #run the query and return the result
    resultSet = DBQueryResult.new
    
    res = @dbh.query(queryString)
    
    if(res.num_rows == 0)
      return nil
    end
    resultSet.resultSet = res
    
    return resultSet
  end
  
  
  def runNodeQuery()      
    # replace %t1% with crtTime and %t2% with crtTime + avgInterval
    s = @crtTime
    e = @crtTime + @avgInterval
    query = @nodeQuery.gsub("%t1%", s.to_s).gsub("%t2%", e.to_s)
    #puts query
    return runQuery(query)
  end
  
  
  def runAllNodesQuery()      
    # returns a QueryResult object
    return runQuery(@allNodesQuery)
  end
  
  
  def runLinkQuery()
    # replace %t1% with crtTime and %t2% with crtTime + avgInterval
    s = @crtTime
    e = @crtTime + @avgInterval
    query = @linkQuery.gsub("%t1%", s.to_s).gsub("%t2%", e.to_s)
    
    return runQuery(query)
  end
  
  
  def setAveragingInterval(newVal)
    @avgInterval = newVal
  end
  
  def stepPlus()
    #puts "Entered stepPlus"
    if (@crtTime != 0)  
      if ((@crtTime + @avgInterval) > @maxTime)
        #puts "crtTime set to max"
        @crtTime = @maxTime
      else  
        @crtTime = @crtTime + @avgInterval
      end
    end
    #puts "crtTime +="+ @crtTime.to_s
  end
  
  #decrease the current Timestamp by the Timestep
  def stepMinus()
    #puts "Entered stepMinus"
    if (@crtTime != 0)
      if ((@crtTime - 2*@avgInterval) < @minTime)
        #puts "crtTime set to min"
        @crtTime = @minTime
      else
        @crtTime = @crtTime - 2*(@avgInterval)
      end
    end
    #puts "crtTime - ="+ @crtTime.to_s
  end
  
  #pause the experiment 
  #do not advance the time
  def pause()
    # nothing here
  end
  
  #reset the current Timestamp to the minTime
  def stop()
    #puts "crtTime set to min"
    @crtTime = @minTime
  end
  
end

