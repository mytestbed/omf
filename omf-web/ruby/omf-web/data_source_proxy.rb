

require 'omf_common'


module OMF::Web
        
  # This object maintains synchronization between a JS DataSource object 
  # in a web browser and the corresponding +OmlTable+ in this server.
  #
  #
  class DataSourceProxy < MObject
    
    def self.for_source(ds)
      unless ds.kind_of?(OMF::OML::OmlTable)
        raise "Expected OmlTable, but got '#{ds.class}::#{ds}'"
      end
      name = "ds:#{ds.object_id}"
      proxy = OMF::Web::SessionStore[name] ||= self.new(ds)
      return proxy
    end
    
    def reset()
      # TODO: Figure out partial sending 
    end
    
    def on_update(req)
      res = {:events => @data_source.rows}
      [res.to_json, "text/json"]
    end
    
    
    def to_javascript(update_interval)
      name = "ds#{@data_source.object_id}"
      %{
        OML.data_sources['#{name}'] = new OML.data_source('#{name}', 
                                                          '/_update?sid=#{Thread.current["sessionID"]}&did=#{@data_source.object_id}',
                                                          #{update_interval},
                                                          #{@data_source.schema.to_json},
                                                          #{@data_source.rows.to_json});
      }
    end
    
    def initialize(data_source)
      @data_source = data_source
    end
  end
  
end
