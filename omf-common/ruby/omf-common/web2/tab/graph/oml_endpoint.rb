



module OMF::Common::OML
        
  # This class parses an OML network stream and creates various OML mstreams which can 
  # be visualized. After creating the object, the @run@ method needs to be called to 
  # start processing the stream.
  #
  class OMLEndpoint < MObject
    
    TYPE_PROC = {
      'string' => lambda do |s| s end,
      'double' => lambda do |s| s.to_f end
    }

    def initialize(opts = {})
      @opts = opts
      @header = {}
      @streams = []
    end
    
    # This methods blocks until the peer disconnects. Each new stream is reported 
    # to the @reportProc@
    #
    def parse(socket, &reportStreamProc)
      @reportStreamProc = reportStreamProc
      parse_header(socket)
      parse_rows(socket)
    end
    
    # Return the value for the respective @key@ in the protocol header.
    #
    def [](key)
      @header[key]
    end

    private
    def parse_header(socket, &reportStreamProc)
      while (l = socket.gets.strip)
        return if l.length == 0
        
        key, *value = l.split(':')
        if (key == 'schema')
          parse_schema(value.join(':'))
        else
          @header[key] = value[0].strip
          puts "HEADER: #{key}: #{@header[key]}"
        end
      end
    end

    def parse_schema(desc)
      #puts "SCHEMA: #{desc}"
      els = desc.split(' ')
      #puts "ELS: #{els.inspect}"
      index = els.shift.to_i - 1
      
      sname = els.shift
      schema = els.collect do |el|
        name, type = el.split(':')
        typeProc = TYPE_PROC[type]
        raise "Unknown OML type '#{type}'" unless typeProc
        [name.to_sym, type.to_sym, typeProc]
      end
      
      @streams[index] = stream = OMLTable.new(sname, schema)
      @reportStreamProc.call(stream)
    end

    def parse_rows(socket)
      while (l = socket.gets)
        return if l.length == 0
        
        els = l.split("\t")
        index = els.delete_at(1).to_i - 1
        @streams[index].parse_row(els)
      end
    end                                
  end # OMLEndpoint
  
  # This class represents a database like table holding a sequence of OML measurements (rows) according
  # a common schema.
  #
  class OMLTable < MObject
    attr_accessor :max_size
    attr_reader :rows
    
    # 
    # tname - Name of table
    # schema - Array containing [name, typeProc] for every column in table
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
    
    def parse_row(els)
      return unless @onRowProc
      
      ts, index, *rest = els
      row = {:oml_sname => @name, :oml_ts => ts.to_f, :oml_seq_no => index.to_i}
      rest.each_index do |i|
        name, unused, typeProc = @schema[i]
        value = rest[i]
        row[name] = typeProc.call(value)
      end
      add_row(row)
    end
  end # OMLTable

end
