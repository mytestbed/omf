
require 'monitor'

require 'omf-oml'
require 'omf-oml/schema'


module OMF::OML
          
  # This class represents a database like table holding a sequence of OML measurements (rows) according
  # a common schema.
  #
  class OmlTable < MObject
    include MonitorMixin
    
    attr_reader :name
    attr_accessor :max_size
    attr_reader :rows
    attr_reader :schema
    
    # 
    # tname - Name of table
    # schema - OmlSchema or Array containing [name, type*] for every column in table
    #   TODO: define format of TYPE
    # opts -
    #   :max_size - keep table to that size by dropping older rows
    #
    def initialize(tname, schema, opts = {}, &on_before_row_added)
      super tname
      
      #@endpoint = endpoint
      @name = tname
      unless schema.kind_of? OmlSchema
        schema = OmlSchema.new(schema)
      end
      @schema = schema
      @opts = opts
      @on_before_row_added = on_before_row_added
      @rows = []
      @max_size = opts[:max_size]
      @on_row_added = {}
    end
    
    # Register +callback+ to be called to process any newly
    # offered row before it being added to internal storage.
    # The callback's argument is the new row (TODO: in what form)
    # and should return what is being added instead of the original
    # row. If the +callback+ returns nil, nothing is being added.
    #
    def on_before_row_added(&callback)
      @on_before_row_added = callback
    end
    
    def on_row_added(key, &proc)
      #debug "on_row_added: #{proc.inspect}"
      if proc
        @on_row_added[key] = proc
      else
        @on_row_added.delete key
      end
    end
    
    # NOTE: +on_row_added+ callbacks are done within the monitor. 
    #
    def add_row(row)
      synchronize do
        _add_row(row)
      end
    end
    
    # Add an array of rows to this table
    #
    def add_rows(rows)
      synchronize do
        rows.each { |row| _add_row(row) }
      end
    end
    
    def describe()
      rows
    end
    
    def data_sources
      self
    end
    
    private
    
    # NOT synchronized
    #
    def _add_row(row)
      #puts row.inspect
      if @on_before_row_added
        row = @on_before_row_added.call(row)
      end
      return unless row 

      @rows << row
      if @max_size && @max_size > 0 && (s = @rows.size) > @max_size
        @rows.shift # not necessarily fool proof, but fast
      end

      #puts "add_row"
      @on_row_added.each_value do |proc|
        #puts "call: #{proc.inspect}"
        proc.call(row)
      end
    end
    
  end # OMLTable

end
