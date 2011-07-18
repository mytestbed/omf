



module OMF::Common::OML
          
  # This class represents a database like table holding a sequence of OML measurements (rows) according
  # a common schema.
  #
  class OmlTable < MObject
    attr_accessor :max_size
    attr_reader :rows
    
    # 
    # tname - Name of table
    # schema - Array containing [name, type*] for every column in table
    # opts -
    #   :max_size - keep table to that size by dropping older rows
    #
    def initialize(tname, schema, opts = {})
      #@endpoint = endpoint
      @name = tname
      @schema = schema
      @opts = opts
      @rows = []
      @max_size = opts[:max_size]
      @on_row_added = {}
    end
    
    # def [](key)
      # @endpoint[key]
    # end

    def on_row(&callback)
      @onRowProc = callback
    end
    
    def on_row_added(key, &proc)
      puts "on_row_added: #{proc.inspect}"
      if proc
        @on_row_added[key] = proc
      else
        @on_row_added.delete key
      end
    end
    
    # NOTE: May need a monitor if used in multi-threaded environments
    #
    def add_row(row)
      #puts row.inspect
      if @onRowProc
        row = @onRowProc.call(row)
      end
      if row 
        @rows << row
        if @max_size && @max_size > 0 && (s = @rows.size) > @max_size
          @rows.shift # not necessarily fool proof, but fast
        end
      end
      #puts "add_row"
      @on_row_added.each_value do |proc|
        #puts "call: #{proc.inspect}"
        proc.call(row)
      end
    end
    
  end # OMLTable

end
