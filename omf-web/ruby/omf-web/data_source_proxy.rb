

require 'omf_common'
require 'omf-oml/network'

module OMF::Web
        
  # This object maintains synchronization between a JS DataSource object 
  # in a web browser and the corresponding +OmlTable+ in this server.
  #
  #
  class DataSourceProxy < MObject
    
    @@datasources = {}
    
    def self.register_datasource(data_source, opts = {})
      name = data_source.name.to_sym
      if (@@datasources.key? name)
        raise "Repeated try to register data source '#{name}'"
      end
      if data_source.is_a? OMF::OML::OmlNetwork
        dsh = data_source.to_tables(opts)
        @@datasources[name] = dsh
      else
        @@datasources[name] = data_source
      end
    end
    
    # Return proxies for 'ds_name'. Note, there can be more then
    # one proxy be needed for a datasource, such as a network which
    # has one ds for the nodes and one for the links
    #
    # @return: Array of proxies
    #
    def self.for_source(ds_descr)
      #raise "FOO #{ds_descr.inspect}"
      unless ds_descr.is_a? Hash
        raise "Expected Hash, but got '#{ds_descr.class}::#{ds_descr.inspect}'"
      end
      ds_name = ds_descr[:name].to_sym
      ds = @@datasources[ds_name]
      unless ds
        throw "Unknown data source '#{ds_name}' (#{@@datasources.keys.inspect})"
      end
      if ds.is_a? Hash
        n_name = "#{ds_name}_nodes".to_sym
        l_name = "#{ds_name}_links".to_sym
        if (nodes = OMF::Web::SessionStore[n_name])
          # assume links exist as well
          links = OMF::Web::SessionStore[l_name]                
        else
          nodes = OMF::Web::SessionStore[n_name] = self.new(n_name, ds[:nodes])
          links = OMF::Web::SessionStore[l_name] = self.new(l_name, ds[:links])
        end
        return [nodes, links]
      end
      
      proxy = OMF::Web::SessionStore[ds_name] ||= self.new(ds_name, ds)
      return [proxy]
    end
    
    def reset()
      # TODO: Figure out partial sending 
    end
    
    def on_update(req)
      res = {:events => @data_source.rows}
      [res.to_json, "text/json"]
    end
    
    
    def to_javascript(update_interval)
      #name = "ds#{@data_source.object_id}"
      # %{
        # OML.data_sources['#{@name}'] = new OML.data_source('#{@name}', 
                                                          # '/_update/#{@name}?sid=#{Thread.current["sessionID"]}',
                                                          # #{update_interval},
                                                          # #{@data_source.schema.to_json},
                                                          # #{@data_source.rows.to_json});
      # }
      %{
        OML.data_sources.register('#{@name}', 
                                  '/_update/#{@name}?sid=#{Thread.current["sessionID"]}',
                                  #{@data_source.schema.to_json},
                                  #{@data_source.rows.to_json});
      }
     
    end
    
    
    def initialize(name, data_source)
      @name = name
      @data_source = data_source
    end
  end
  
end
