
require 'omf-common/oml/arel_remote'

module OMF::Web::Graph
  
  # Serial data sets consist of a series of ordered records. 
  #
  class SeriesBuilder
    # Use this as the default column name for ordering streams
    DEF_STREAM_COLUMN = :oml_ts_server 
    
    attr_reader :session, :opts
    
    def session()
      @gDescr.session
    end
    
    def opts()
      @gDescr.opts
    end

    # Define a stream on a database table whose construction (query) is subsequently
    # defined. The only argument is a table column or table. If only the table is 
    # provided we assume there exists a DEF_STREAM_COLUMN. 
    # use 
    def stream(table_column)
      if table_column.kind_of? OMF::Common::OML::Arel::Table
        table = table_column
        column = table[DEF_STREAM_COLUMN]
      elsif table_column.kind_of? OMF::Common::OML::Arel::Column
        column = table_column
        table = column._table
      else
        raise "Expected argument of type 'Column', but got '#{table.column.class}'"
      end
      skip = session[:stream_skip] ||= 0
      take = opts[:streamChunkSize] ||= 1000
      table.order(column).skip(skip).take(take)
    end
    
    # Return a series which may already contain data from a previous instantiation.
    #
    def series(name, &block)
      
    end
    
    # Add a series.
    # 
    # darray - Array of data points where a data point is an array itself
    # opts - ???
    #
    def addSeries(darray, opts = {})
      l = opts.dup
      l[:id] ||= @series.length
      l[:values] = darray
      @series << l
    end      
    
  
    def self.build(buildProc, gDescr)
      b = self.new(gDescr)
      begin
        buildProc.call(b)
      rescue Exception => ex
        raise ex
      end
      b
    end
    
    def initialize(gDescr)
      @series = []
      @gDescr = gDescr
    end
    
    def to_a()
      @series
    end
    
    def to_json(state = nil)
      @series.to_json(state)
    end
    
  end # SeriesBuilder
end
