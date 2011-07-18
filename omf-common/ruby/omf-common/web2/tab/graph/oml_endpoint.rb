
require 'omf-common/mobject'
module OMF
  module Common; end
end



module OMF::Common::OML
        
  # This class parses an OML network stream and creates various OML mstreams which can 
  # be visualized. After creating the object, the @run@ method needs to be called to 
  # start processing the stream.
  #
  class OmlEndpoint < MObject
    
    # Register a proc to be called when a new stream was
    # discovered on this endpoint.
    #
    def on_new_stream(key = :_, &proc)
      if proc
        @on_new_stream_procs[key] = proc
      else
        @on_new_stream_procs.delete key
      end
    end
    
    def initialize(port = 3000, host = "127.0.0.1")
      require 'socket'
      @serv = TCPServer.new(host, port)
      @running = false
      @on_new_stream_procs = {}
    end
    
    def report_new_stream(stream)
      @on_new_stream_procs.each_value do |proc|
        proc.call(stream)
      end
    end
    
    def run(in_thread = true)
      if in_thread
        Thread.new do
          _run
        end
      else
        _run
      end
    end
    
    private
    
    def _run
      @running = true      
      while @running do
        sock = @serv.accept
        debug "OML client connected: #{sock}"
        
        Thread.new do
          begin
            conn = OmlConnection.new(self)
            conn.run(sock)
            debug "OML client disconnected: #{sock}"            
          rescue Exception => ex
            error "Exception in OmlConnection: #{ex}"
            debug "Exception in OmlConnection: #{ex.backtrace.join("\n\t")}"
          ensure
            sock.close
          end
        end
        
      end
    end
  end
  
  class OmlConnection < MObject
    
    # Return the value for the respective @key@ in the protocol header.
    #
    def [](key)
      @header[key]
    end

    def initialize(endpoint)
      @endpoint = endpoint
      @header = {}
      @streams = []
      @on_new_stream_procs = {}
    end
    
    # This methods blocks until the peer disconnects. Each new stream is reported 
    # to the @reportProc@
    #
    def run(socket)
      parse_header(socket)
      parse_rows(socket)
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
      puts "SCHEMA: #{desc}"
      els = desc.split(' ')
      #puts "ELS: #{els.inspect}"
      index = els.shift.to_i - 1
      
      sname = els.shift
      schema = els.collect do |el|
        name, type = el.split(':')
        [name.to_sym, type.to_sym]
      end
      
      @streams[index] = row = OmlVector.new(schema, sname)
      @endpoint.report_new_stream(row)
    end

    def parse_rows(socket)
      while (l = socket.gets)
        return if l.length == 0
        
        els = l.split("\t")
        index = els.delete_at(1).to_i - 1
        row = @streams[index].parse_row(els)
      end
    end
    
    # def parse_row(els, sindex)
      # ts, index, *rest = els
      # row = {:oml_sname => @name, :oml_ts => ts.to_f, :oml_seq_no => index.to_i}
      # rest.each_index do |i|
        # name, unused, typeProc = @schema[i]
        # value = rest[i]
        # row[name] = typeProc.call(value)
      # end
      # add_row(row)
    # end
                     
  end # OMLEndpoint
  
  # This class represents the schema of an OML measurement stream.
  #
  class OmlSchema < MObject
    
    # Return the col name at a specific index
    #
    def name_at(index)
      @schema[index][0]
    end
    
    # Return the column names as an array
    #
    def names
      @schema.collect do |name, type, typeProc| name end
    end

    # Return the col type at a specific index
    #
    def type_at(index)
      @schema[index][1]
    end
    
    # Register a proc to be called when a new vector arrived
    # on this stream.
    #
    def on_new_vector(key = :_, &proc)
      if proc
        @on_new_vector_proc[key] = proc
      else
        @on_new_vector_proc.delete key
      end
    end
    
    
    attr_reader :stream_name

    def initialize(schema, sname)
      @schema = schema
      @stream_name = sname
      @on_new_vector_proc = {}
    end
  end # OmlSchema
  
  # This class represents a single vector from an OML measurement stream.
  # It provides various methods to access the vectors elements.
  #
  # NOTE: Do not store the vector itself, but make a copy as the instance may be 
  # reused over various rows by the sender.
  #
  class OmlVector < OmlSchema
    
    # Return a specific element of the vector identified either
    # by it's name, or its col index
    #
    def [](name_or_index)
      @vprocs[name_or_index].call(@raw)
    end
    
    # Return the elements of the vector as an array
    def to_a(include_index_ts = false)
      res = []
      r = @raw
      if include_index_ts
        res << @vprocs[:oml_ts].call(r)
        res << @vprocs[:oml_seq_no].call(r)
      end
      @schema.each do |name, type|
        res << @vprocs[name].call(r)
      end
      res
    end
    
    # Return an array including the values for the names elements
    # given as parameters.
    #
    def select(*col_names)
      r = @raw
      col_names.collect do |n|
        @vprocs[n].call(r)
      end
    end
        
    attr_reader :ts, :seq_no

    def ts
      @raw[0].to_f
    end
    
    def seq_no
      @raw[1].to_i
    end
    
    def initialize(schema, sname)
      super
      @raw = []
#      puts "SCHEMA: #{schema.inspect}"
      
      i = 0
      @vprocs = {}
      schema.each do |name, type|
        j = i + 2; # need to create a locally scoped variable for the following lambdas
        @vprocs[name] = @vprocs[i] = case type      
          when :string : lambda do |r| r[j] end
          when :double : lambda do |r| r[j].to_f end
          else raise "Unrecognized OML type '#{type}'"
        end
        i += 1
      end
      @vprocs[:oml_ts] = lambda do |r| r[0].to_f end
      @vprocs[:oml_seq_no] = lambda do |r| r[1].to_i end
    end
    
    # Parse the array of strings into the proper typed vector elements
    #
    # NOTE: We assume that each element is only called at most once, with some
    # never called. We therefore delay typecasting to the get function without
    # keeping the casted values (would increase lookup time)
    #
    def parse_row(els)
      @raw = els
      #puts "RAW: #{els.length} #{els.join(' ')}"
      
      # ts, index, *rest = els
      # @ts = ts.to_f
      # @seq_no = index.to_i
# 
      # @row.clear
      # rest.each_index do |i|
        # name, unused, typeProc = @schema[i]
        # value = rest[i]
        # @row << typeProc.call(value)
      # end
      
      @on_new_vector_proc.each_value do |proc|
        proc.call(self)
      end
      
    end
  end # OmlVector
end

if $0 == __FILE__

  require 'omf-common/web2/tab/graph/oml_table'
  ep = OMF::Common::OML::OmlEndpoint.new(3000)
  toml = OMF::Common::OML::OmlTable.new('oml', [[:x], [:y]], :max_size => 20)
  ep.on_new_stream() do |s|
    puts "New stream: #{s}"
    s.on_new_vector() do |v|
      puts "New vector: #{v.select(:oml_ts, :value).join('|')}"      
      toml.add_row(v.select(:oml_ts, :value))
    end
  end
  ep.run(false)

end

