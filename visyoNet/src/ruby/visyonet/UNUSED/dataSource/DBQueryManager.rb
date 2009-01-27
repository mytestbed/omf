require "visyonet/dbQueryManager/DBQM"
require "visyonet/dbQueryManager/DBQueryResult"
require "visyonet/dbQueryManager/DBQueryData"

# interface definitions
class DBQueryManager

  def self.processConfig(root)
    if (root.name != 'QueryManager')
      MObject.error('processConfig', 
        "Doesn't appear to be a proper QueryManager config - starts with '#{root.name}'")
      return false
    end
    root.elements.each { |el|
      case el.name
      when "Query"
      when "DBConnection"
        @@host = getConnParam(el, "host") || 'localhost'
        @@username = getConnParam(el, "user")
        @@passwd = getConnParam(el, "password") || ""
        @@database = getConnParam(el, "database")
      else
        MObject.error('DBQueryManager', "Unknown config tag '#{el.name}'")
      end
    }
  end
  
  def self.openDbConnection(qm)
    if (qm == nil)
      raise "Missing <DBQueryManager> tag"
    end
    dbc = qm.elements["DBConnection"]
    if (dbc == nil) 
      raise "Missing <DBConnection> tag"
    end
    host = getConnParam(dbc, "host") || 'localhost'
    username = getConnParam(dbc, "user")
    passwd = getConnParam(dbc, "password") || ""
    database = getConnParam(dbc, "database")

    # connect to the database server
    dbh = nil
    if (username != nil && database != nil) 
      dbh = Mysql.real_connect(host, username, passwd, database)
    end
    return dbh
  end
    
  def self.getConnParam(dbc, name)
    el = dbc.elements[name]
    return el != nil ? el.get_text.to_s : nil
  end

  def initialize()
    
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
    
    updateConfiguration()
  end
  
  def loadConfigFile(file)
    file = File.new(file)
    content = file.read()
    xmlDoc = REXML::Document.new(content)
    file.close()
  end

  def loadConfigXML(doc, session)  
    qm = xmlDoc.elements["DBQueryManager"]
    session[:dbHandle] = openDbConnection(qm)
    
    # node query
    queryText = config.GetDBNodeQueryText()
    @dbqm.setNodeQuery(queryText)
    
    # link query
    queryText = config.GetDBLinkQueryText()
    @dbqm.setLinkQuery(queryText)
    
    # all nodes query
    queryText = config.GetDBAllNodesQueryText()
    @dbqm.setAllNodesQuery(queryText)
    #puts queryText
    
    # experiment time span query
    queryText = config.GetDBExperimentTimeSpanQueryText()
    @dbqm.setExperimentTimeSpanQuery(queryText)
  end  
  
  
  
  def updateConfiguration()
    # config manager
    config = ConfigurationManager.instance
    
    # set connection parameters
    host = config.GetDBConnectionParams("host")
    username= config.GetDBConnectionParams("user")
    passwd = config.GetDBConnectionParams("password")
    database = config.GetDBConnectionParams("database")
    @dbqm.setConnectionParameters(host, username, passwd, database)  
    
    # node query
    queryText = config.GetDBNodeQueryText()
    @dbqm.setNodeQuery(queryText)
    
    # link query
    queryText = config.GetDBLinkQueryText()
    @dbqm.setLinkQuery(queryText)
    
    # all nodes query
    queryText = config.GetDBAllNodesQueryText()
    @dbqm.setAllNodesQuery(queryText)
    #puts queryText
    
    # experiment time span query
    queryText = config.GetDBExperimentTimeSpanQueryText()
    @dbqm.setExperimentTimeSpanQuery(queryText)
  end
  
  
  def runQuery(name, session, &block)
    s = e = nil
    if (session[:realTime] == true)
      e = session[:maxTime]
      if (e == nil)
        raise "Max time not set, should run 'updateMinMaxTime' first."
      end
      s = e - session[:interval]
    else
      s = session[:startTime]
      e = s + session[:interval]
    end
    q = @queries[name]
    if (q == nil)
      raise "Unknown query '#{name}'"
    end
    
    q = q.gsub("%t1%", s.to_s).gsub("%t2%", e.to_s)
    res = _runQuery(queryString, session)
    if (res != nil)
      names = []
      res.fetch_fields.each { |field|
        names << field.name
      }
      while row = res.fetch_row do
        yield(names, row)
      end
      res.free
    end
  end

  def updateMinMaxTime(session)
    session[:minTime] = -1
    session[:maxTime] = -1
    q = @queries['timeSpanQuery']
    if (q == nil)
      return
    end
    res = _runQuery(queryString, session)
    if (res == nil)
      return
    end    
    if((res.num_rows() != 0) || (res.num_fields() < 2))
      result.free()
      raise "experiment time span query returned improper result"
    end
    row = res.fetch_row()
    session[:minTime] = row[0].to_i
    session[:maxTime] = row[1].to_i
  end

  def _runQuery(queryString, session) 
    dbh = session[:dbHandler]
    if(dbh == nil) 
      raise "database not connected"
    end
    
    res = dbh.query(queryString)
    if (res.num_rows == 0)
      return nil
    end
    return res
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
    # returns a DBQueryData object with all nodes
    ret = DBQueryData.new()
    ret.nodeQueryResult = runAllNodesQuery()
    ret.linkQueryResult = nil
    return ret
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
