
require 'visyonet/dataSource/nodeModel'
require 'visyonet/dataSource/linkModel'

# interface definitions
module VisyoNet
  class DataSource < ::MObject
  
    def self.processConfig(root)
      if (root.name != 'DataSource')
        raise "Doesn't appear to be a proper DataSource config - starts with '#{root.name}'"
      end
      if ((type = root.attributes['type']) == nil)
        raise "Missing 'type' attribute in 'DataSource' tag"      
      end
      ds = nil
      case type
      when "sql"
        ds = SqlDataSource.new(nil, root)
      when "code"
        ds = CodeDataSource.new(nil, root)
      else
        MObject.error('DataSource', "Unknown data source type '#{type}'")
      end
    end
    
    def self.[](name)
      return @@sources[name]
    end
    
    @@sources = Hash.new
    
    # Return an array of node and link models representing 
    # the interval in the data source as indicated by the 
    # 'session'
    # 
    def getModel(session)
      nodes = Hash.new
      links = Hash.new
      
      if (session[:realTime] == true)
        updateMinMaxTime(session)
      end
      fetch('node', session) { |names, row|
        id = row[0]
        n = NodeModel.new(id)
        (1..(row.length - 1)).each { |i|
          n[names[i]] = row[i]
        }
        nodes[id] = n
      }
      fetch('link', session) { |names, row|
        id = "l_#{row[0]}_#{row[1]}"
        from = nodes[row[0]]
        to = nodes[row[1]]
        if (from != nil && to != nil)
          l = LinkModel.new(id, from, to)
          (2..(row.length - 1)).each { |i|
            l[names[i]] = row[i].to_i
          }
          links[id] = l
        else 
          debug("Unknown node '#{row[0]}'") if from == nil
          debug("Unknown node '#{row[1]}'") if to == nil
        end
      }
      return {'nodes' => nodes, 'links' => links}
    end

    #
    # Fetch samples from stream 'name' and execute 'block' for each tuple
    # 
    def fetch(name, session, &block)
      raise "'fetch' not implemented"          
    end
    
    def initSession(session, context)
      # default is to do nothing
    end    
    
    def initialize(id = nil, rootEl = nil)
      if rootEl != nil
        if ((id = rootEl.attributes['id']) == nil)
          raise "Missing 'id' attribute in 'DataSource' tag"      
        end
        @description = rootEl.attributes['description']
      end
      if (id == nil)
        raise "Missing 'id' for DataSource."
      end
      info("Data source '#{id}'")
      @@sources[id] = self
    end

  end # class
end # module

# need to be included after the above is defined
require "visyonet/dataSource/sqlDataSource"
require "visyonet/dataSource/codeDataSource"
