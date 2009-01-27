require "singleton"
require "rexml/document"
# require "../DBDataModel/Position"

# singleton class managing configuration files

class ConfigurationManager
  include Singleton 
  
  public
  def initialize()
    @visyonetConf = nil
    @dbqmConf = nil
    @visConf = nil
    
    serverConfigFileName="../Config/visyonet.xml"
    dbConfigFileName="../Config/db.xml"
    visMappingConfigFileName="../Config/visMapping.xml"
    
    
    # read the config files as XML documents
    file = File.new( serverConfigFileName )
    serverConfig = file.read()
    ConfigureServer(serverConfig)
    file.close()
    
    file = File.new( dbConfigFileName )
    dbConfig = file.read()
    ConfigureDB(dbConfig)
    file.close()
    
    file = File.new( visMappingConfigFileName )
    visConfig = file.read()
    ConfigureVisMapping(visConfig)
    file.close()
  end
  
  
  def ConfigureServer(serverConfigString)
    xmlDoc = REXML::Document.new serverConfigString
    
    # visyonet configuration
    @visyonetConf = xmlDoc.elements["Visyonet"]      
  end
  
  
  def ConfigureDB(dbConfigString)    
    xmlDoc = REXML::Document.new dbConfigString
    dbc = xmlDoc.elements["DBQueryManager"]
    if(dbc != nil)
      @dbqmConf = dbc
      # puts "@dbqmConf = " + @dbqmConf.to_s
    end
  end
  
  def ConfigureVisMapping(visConfigString)    
    xmlDoc = REXML::Document.new visConfigString
    vc = xmlDoc.elements["VisMapping"]
    if(vc != nil)
      VisDataModel.instance.setMapping(vc)
    end
    
  end
  
  
  
  
  def GetPortNumber()
    if(@visyonetConf.elements["UpdatePort"] != nil)
      return @visyonetConf.elements["UpdatePort"].get_text.to_s
    end
    return "1099"
  end
  
  
  def getHTTPServerPort()
    if(@visyonetConf.elements["HTTPPort"] != nil)
      return @visyonetConf.elements["HTTPPort"].get_text.to_s
    end
    return "1099"
  end
  
  
  def getHTTPServerDocRoot()
    if(@visyonetConf.elements["HTTPDocRoot"] != nil)
      return @visyonetConf.elements["HTTPDocRoot"].get_text.to_s
    end
    return Dir::pwd + "/htdocs"
  end
  
  
  # DBQueryManager connection parameters
  def GetDBConnectionParams(name)
    if(@dbqmConf == nil) 
      return nil
    end
    
    dbc = @dbqmConf.elements["DBConnection"];
    if(dbc == nil)
      return nil
    end
    
    if(dbc.elements[name] == nil) 
      return nil
    end
    
    return dbc.elements[name].get_text.to_s
  end
  
  # DBQueryManager node query
  def GetDBNodeQueryText()
    qs = GetCurrentQuerySet()
    if(qs != nil)
      if(qs.elements["NodeQuery"] != nil) 
        return qs.elements["NodeQuery"].get_text.to_s
      end
    end
    
    return ""
  end
  
  # DBQueryManager link query
  def GetDBLinkQueryText()
    qs = GetCurrentQuerySet()
    if(qs != nil)
      if(qs.elements["LinkQuery"] != nil) 
        return qs.elements["LinkQuery"].get_text.to_s
      end
    end
    
    return ""
  end
  
  # DBQueryManager getDBIsLive()
  # TODO: Actually set it directly on DBQM.setDbLive
  def GetDBIsLive()
    puts "ConfigurationManager: GetDBIsLive called"
    qs = GetCurrentQuerySet()
    puts qs.to_s
    
    if(qs != nil)
      
      if(qs.attributes["live"] != nil) 
        if(qs.attributes["live"].to_s == "true")
          #puts "returning true"
          return true
        end
      end
    end
    
    #puts "returning false"
    return false
  end
  
  # DBQueryManager all nodes query
  def GetDBAllNodesQueryText()
    qs = GetCurrentQuerySet()
    if(qs != nil)
      if(qs.elements["AllNodesQuery"] != nil) 
        return qs.elements["AllNodesQuery"].get_text.to_s
      end
    end
    
    return ""
  end
  
  # DBQueryManager experiment time span query
  def GetDBExperimentTimeSpanQueryText()
    qs = GetCurrentQuerySet()
    if(qs != nil)
      if(qs.elements["ExperimentTimeSpanQuery"] != nil) 
        return qs.elements["ExperimentTimeSpanQuery"].get_text.to_s
      end
    end
    
    return ""
  end
  
  
  private
  # returns the current query set - the one identified by the use property of Queries
  def GetCurrentQuerySet()
    if(@dbqmConf == nil) 
      return nil
    end
    
    queries = @dbqmConf.elements["Queries"];
    if(queries == nil) 
      return nil
    end
    useQuerySetID=@dbqmConf.elements["Queries"].attributes["use"]
    
    # go through every query set until encountering the crtQuerySetID
    for querySet in queries.elements
      if(querySet.attributes["id"] == useQuerySetID) 
        # found it
        return querySet
      end
    end
    
    # not found 
    #     if the useQuerySet was not specified, use the first QuerySet element
    if(useQuerySetID == nil)
      return queries.elements[1]
    end
    
    return nil
  end
  
  public
  #
  # member variables
  #
  @xmlDoc = nil
  # visyonet config
  @visyonetConf = nil
  # DBQueryManager configuration
  @dbqmConf = nil
end
