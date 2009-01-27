require 'util/mysql'

module VisyoNet
  class SqlDataSource < DataSource
  
    def initialize(name = nil, root = nil)
      super(name, root)
      @queries = Hash.new
      if (root != nil)
        root.elements.each { |el|
          case el.name
          when "Query"
            name = el.attributes['id']
            if (name == nil)
              raise "Missing 'id' attribute in Query tag"
            end
            @queries[name] = el.text
          else
            error("Unknown config tag '#{el.name}'")
          end
        }
      end
      @pooledConnections = Hash.new()
    end
    
    def fetch(name, session, &block)
      s = e = nil
      if (session[:realTime])
        e = session[:maxTime]
        if (e == nil)
          raise "Max time not set, should run 'updateMinMaxTime' first."
        end
        s = e - session[:interval]
      else
        s = session[:startTime]
        e = s + session[:interval]
        if (e > session[:maxTime])
          e = session[:maxTime]
        end
      end
      
      q = @queries[name]
      if (q == nil)
        raise "Unknown query '#{name}'"
      end
      q = q.gsub("%t1%", s.to_s).gsub("%t2%", e.to_s)
      debug("fetch(#{s}->#{e}): #{q}")
      res = runQuery(q, session)
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
      fetch('timeSpanQuery', session) { |names, row|
        if(names.size != 2)
          raise "experiment time span query returned improper result"
        end
        session[:minTime] = row[0].to_i
        session[:maxTime] = row[1].to_i
      }
    end
  
    def runQuery(queryString, session) 
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
    
    def initSession(session, context)
      if ((el = context.configEl.elements['SqlDataSource']) == nil)
        raise "Missing 'SqlDataSource' tag in Context configuration"
      end
      dbh = nil
      if (el.attributes['sharable'] == 'true')
        if ((id = el.attributes['id']) == nil)
          raise "Missing 'id' attribute in 'SqlDataSourceTag"
        end
        if ((dbh = @pooledConnections[id]) == nil)
          # first one around
          dbh = @pooledConnections[id] = openDbConnection(el)
        end
      else
        dbh = openDbConnection(el)
      end
      session[:dbHandler] = dbh
    end
    
    # connect to the database server
    def openDbConnection(el)
      dbh = nil
      host = getConnParam(el, "host") || 'localhost'
      username = getConnParam(el, "user")
      passwd = getConnParam(el, "password") || ""
      database = getConnParam(el, "database")
      
      if (username != nil && database != nil) 
        debug("Open connection to '", username, '@', host, ':', database, "'")
        dbh = ::Mysql.real_connect(host, username, passwd, database)
      end
      return dbh
    end
      
    def getConnParam(dbc, name)
      el = dbc.elements[name]
      return el != nil ? el.get_text.to_s : nil
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
            warn("experiment time span query returned improper result")
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
    
    def stop()
      #puts "crtTime set to min"
      @crtTime = @minTime
    end
    
  end # class
end # module