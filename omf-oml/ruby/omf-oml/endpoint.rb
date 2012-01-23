
require 'omf-common/mobject'
require 'omf-oml'

require 'omf-oml/oml_tuple'

module OMF::OML
        
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
  
  # PRIVATE 
  # An instance of this class is created by +OmlEndpoint+ to deal with
  # and individual client connection (socket). An EndPoint is creating
  # and instance and then immediately calls the +run+ methods.
  #
  #
  class OmlSession < MObject  # :nodoc
    
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
          debug "HEADER: #{key}: #{@header[key]}"
        end
      end
    end

    def parse_schema(desc)
      debug "SCHEMA: #{desc}"
      els = desc.split(' ')
      #puts "ELS: #{els.inspect}"
      index = els.shift.to_i - 1
      
      sname = els.shift
      schema = els.collect do |el|
        name, type = el.split(':')
        {:name => name.to_sym, :type => type.to_sym}
      end
      
      @streams[index] = row = OmlTuple.new(schema, sname)
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
  
  
end

if $0 == __FILE__

  require 'omf-oml/table'
  ep = OMF::OML::OmlEndpoint.new(3000)
  toml = OMF::OML::OmlTable.new('oml', [[:x], [:y]], :max_size => 20)
  ep.on_new_stream() do |s|
    puts "New stream: #{s}"
    s.on_new_vector() do |v|
      puts "New vector: #{v.select(:oml_ts, :value).join('|')}"      
      toml.add_row(v.select(:oml_ts, :value))
    end
  end
  ep.run(false)

end

