# The 'Context' class contains all the information
# for a specific datasource made available at a
# particular path of the web server.
#
# == Other Info
# 
# Version:: $Id:$
# Author:: Max Ott <max(at)ott.name>
# Copyright 2006, Max Ott, All rights reserved.
# 
require "visyonet/dataSource/dataSource"
require "visyonet/visModel/visMapping"

module VisyoNet
  
  class Context < MObject
    
    DEF_INTERVAL = 10
    
    @@contexts = Hash.new
    
    def self.processConfig(el)
      self.new(el)
    end
    
    def self.each()
      @@contexts.each_value { |c|
        yield(c)
      }
    end
    
    # Return context for 'path'
    def self.[](path)
      return @@contexts[path]
    end
    

    attr_reader :defDataSource, :defVisMapping, :path
    attr_reader :isRealTimeSource
    attr_reader :defInterval
    attr_reader :configEl

    def createSession(req)
      session = Hash.new
      session[:realTime] = @realTime
      session[:interval] = @interval

      session[:startTime] = 0
      session[:maxTime] = -1
      session[:minTime] = -1
      
      return session
    end
    
        
    def initialize(root)
      @configEl = root
      if (root.name != 'Context')
        raise("Doesn't appear to be a proper Context config - starts with '#{root.name}'")
      end
      if ((@path = root.attributes['path']) == nil)
        raise "Missing 'path' attribute in Context"
      end
      @defInterval = (root.attributes['interval'] || DEF_INTERVAL).to_i
      root.elements.each { |el|
        case el.name
        
        when 'DefDataSource'
          if ((ref = el.attributes['idref']) == nil)
            raise "Missing 'idref' attribute for 'DefDataSource'"
          end
          if ((@defDataSource = DataSource[ref]) == nil)
            raise "Unknown data source '#{ref}'"
          end
          @isRealTimeSource = el.attributes['realTime'] == 'true'
          
        when 'DefVisMapping'
          if ((ref = el.attributes['idref']) == nil)
            raise "Missing 'idref' attribute for 'DefVisMapping'"
          end
          if ((@defVisMapping = VisMapping[ref]) == nil)
            raise "Unknown vis mapping '#{ref}'"
          end
        end
      }
      @@contexts[path] = self
    end

      
  end # class Context
end # module Visyonet