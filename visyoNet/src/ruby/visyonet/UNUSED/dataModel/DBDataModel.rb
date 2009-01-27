require "visyonet/dbDataModel/Attribute"
require "visyonet/dbDataModel/Position"
require "visyonet/dbDataModel/DBLink"
require "visyonet/dbDataModel/DBNode"

require "visyonet/dbQueryManager/DBQueryManager"

class DBData
  attr_accessor :DBNodes, :DBLinks
  
  def initialize()
    @DBNodes = nil
    @DBLinks = nil
  end
end



class DBDataModel

  def initialize(dbquerymanager)
    @dbquerymanager = dbquerymanager
  end
  
  def stepPlus()
    #puts "DBDataModel called stepPlus"
    @dbquerymanager.stepPlus()
  end
  
  def stepMinus()
    puts "DBDataModel called stepMinus"
    @dbquerymanager.stepMinus()
  end
  
  def pause()
    @dbquerymanager.pause()
  end
  
  def stop()
    @dbquerymanager.stop()
  end
  
  def getAllNodes()
    
    #first initialize return value
    ret = nil
    
    res = @dbquerymanager.getAllNodes()
    
    #check if Query is good.
    if (res != nil)
      #create the return object
      ret = DBData.new()
      # create only nodes; links are set to nil
      nodes = Hash.new
      links = nil
      
      # nodes
      #puts "Nodes"
      while row = res.nodeQueryResult.resultSet.fetch_row do
        # print the first 2 fields
        #printf "nodeID: %s, pos: (%s, %s), nrPackets: %s\n", row[0], row[1], row[2], row[3]
        id = row[0]
        nodes[id] = DBNode.new(id, Position.new(row[1].to_i, row[2].to_i, 0))
        nodes[id].addAttribute(Attribute.new("status", row[3].to_i))
        
        # TO DO: take attr names from names of result table columns 3 to ...
        #puts "Load out for node " + id + ": " + nodes[id].attributes[1].value.to_s
      end
      res.nodeQueryResult.resultSet.free
      
      # fill the nodes and leave the links to nil
      ret.DBNodes = nodes
      ret.DBLinks = links
    end # do the above only if the queries are not nil
    
    return ret
    
  end
  
  
  def getUpdates()
    puts "DBDataModel:getUpdates called"
    
    #first initialize return value
    ret = nil
    
    res = @dbquerymanager.getUpdates()
    
    #check if Query is good.
    if (res != nil)
      
      #create the return object
      ret = DBData.new()
      # create node and link lists from the database...
      nodes = Hash.new
      links = Hash.new
      
      # nodes
      #puts "Nodes"
      while row = res.nodeQueryResult.resultSet.fetch_row do
        # print the first 2 fields
        #printf "nodeID: %s, pos: (%s, %s), nrPackets: %s\n", row[0], row[1], row[2], row[3]
        id = row[0]
        nodes[id] = DBNode.new(id, Position.new(row[1].to_i, row[2].to_i, 0))
        nodes[id].addAttribute(Attribute.new("status", row[3].to_i))
        nodes[id].addAttribute(Attribute.new("loadOut", row[4].to_i))
        nodes[id].addAttribute(Attribute.new("loadIn", row[5].to_i))
        
        # TO DO: take attr names from names of result table columns 3 to ...
        #puts "Load out for node " + id + ": " + nodes[id].attributes[1].value.to_s
      end
      res.nodeQueryResult.resultSet.free
      
      # links
      #puts "Links"
      while row = res.linkQueryResult.resultSet.fetch_row do
        #printf "from: %s, to: %s, rate: %s\n", row[0], row[1], row[2]
        id = row[0] + "|" + row[1]
        # puts "ID: <" + id + ">"
        # source of a link cannot be null
        if(nodes[row[0]] != nil) 
          links[id] = DBLink.new(id, nodes[row[0]], nodes[row[1]])
          links[id].addAttribute(Attribute.new("rate", row[2].to_i))
        end
      end
      res.linkQueryResult.resultSet.free
      
      # fill proper entities in the return object
      ret.DBNodes = nodes
      ret.DBLinks = links
    end # do the above only if the queries are not nil
    
    return ret
    
  end
  
  def getModel(name, session)
    ret = DBData.new()
    # create node and link lists from the database...
    nodes = Hash.new
    links = Hash.new
    
    if (session[:realTime] == true)
      @dbquerymanager.updateMinMaxTime(session)
    end
    @dbquerymanager.runNodeQuery(name, session) { |names, row|
      id = row[0]
      pos = Position.new(row[1].to_i, row[2].to_i, 0)
      n = DBNode.new(id, pos)
      (3..row.length).each { |i|
        n[names[i]] = row[i]
      }
      nodes[id] = n
    }
    @dbquerymanager.runLinkQuery(name, session) { |names, row|
      id = row[0] + "|" + row[1]
      from = nodes[row[0]]
      to = nodes[row[1]]
      if (from != nil && to != nil)
        l = DBLink.new(id, from, to)
        (2..row.length).each { |i|
          l[names[i]] = row[i].to_i
        }
        links[id] = l      
      end
    }
    # fill proper entities in the return object
    ret.DBNodes = nodes
    ret.DBLinks = links
    return ret
  end
end
