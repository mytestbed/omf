
require 'omf-common/mobject'
module OMF
  module Common; end
end

require 'sqlite3'
require 'omf-common/oml/oml_endpoint'
require 'omf-common/oml/oml_tuple'

module OMF::Common::OML
        
  # This class fetches the content of an sqlite3 database and serves it as multiple 
  # OML streams. 
  #
  # After creating the object, the @run@ method needs to be called to 
  # start producing the streams.
  #
  class OmlSqlSource < MObject
    
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
    
    def initialize(db_file)
      raise "Can't find database '#{db_file}'" unless File.readable?(db_file)
      @db = SQLite3::Database.new(db_file)
      @running = false
      @on_new_stream_procs = {}
      @tables = {}
    end
    
    def report_new_stream(stream)
      @on_new_stream_procs.each_value do |proc|
        proc.call(stream)
      end
    end
    
    def run()
      # first find tables
      @db.execute( "SELECT * FROM sqlite_master WHERE type='table';") do |r|
        table = r[1]
        report_new_table(table) unless table.start_with?('_')
      end
    end
    
    def report_new_table(table_name)
      t = @tables[table_name] = OmlSqlRow.new(table_name, @db, self)
      @on_new_stream_procs.each_value do |proc|
        proc.call(t)
      end
    end
    
  end
  
  # Read the content of a table and feed it out.
  #
  class OmlSqlRow < OmlTuple
    
    # Return a specific element of the vector identified either
    # by it's name, or its col index
    #
    def [](name_or_index)
      @vprocs[name_or_index].call(@raw)
    end
    
    # Return the elements of the vector as an array
    def to_a(include_oml_internals = false)
      include_oml_internals ? @row.dup : @row[4 .. -1]
    end
    
    # Return an array including the values for the names elements
    # given as parameters.
    #
    def select(*col_names)
      r = @row
      col_names.collect do |n|
        p = @vprocs[n]
        p ? p.call(r) : nil
      end
    end
        
    def ts
      self[:oml_ts_server]
    end
    
    def seq_no
      self[:oml_seq]
    end    
    
    # Register a proc to be called when a new tuple arrived
    # on this stream.
    #
    def on_new_tuple(key = :_, &proc)
      if proc
        @on_new_vector_proc[key] = proc
      else
        @on_new_vector_proc.delete key
      end
      run() unless @on_new_vector_proc.empty?
    end

    # Create and return an +OmlTable+ which captures this tuple stream
    #
    # The argument to this method are either a list of columns to 
    # to capture in the table, or an array of column names and
    # an option hash to be provided to the +OmlTable+ constructor
    #
    def capture_in_table(*args)
      if args.length == 1 && args[0].kind_of?(Array)
        select = args[0]
      elsif args.length == 2 && args[1].kind_of?(Hash)
        select = args[0]
        opts = args[1]
      else
        opts = {}
        select = args
      end
      
      tschema = select.collect do |cname| {:name => cname} end
      t = OMF::Common::OML::OmlTable.new(stream_name, tschema)
      self.on_new_tuple() do |v|
        #puts "New vector(#{stream.stream_name}): #{v.select(*select).join('|')}"
        t.add_row(v.select(*select))   
      end
      t
    end

    def initialize(table_name, db, source)
      @sname = table_name
      @db = db
      @source = source
      @stmt = db.prepare("select * from #{table_name};")
      @on_new_vector_proc = {}

      schema = find_schema
      super table_name, schema 
    end

    protected
        
    def find_schema()
      cnames = @stmt.columns
      ctypes = @stmt.types
      schema = []
      cnames.size.times do |i|
        name = cnames[i].to_sym
        schema << {:name => name, :type => ctypes[i]}
      end
      schema
    end
    
    # override
    def process_schema(schema)
      i = 0
      @vprocs = {}
      schema.each_column do |col|
        name = col[:name]
        j = i + 0
        l = @vprocs[name] = lambda do |r| r[j] end
        @vprocs[i - 4] = l if i > 4
        i += 1
      end
    end
    
    def run(in_thread = true)
      return if @running
      if in_thread
        Thread.new do
          begin
            _run
          rescue Exception => ex
            error "Exception in OmlSqlRow: #{ex}"
            debug "Exception in OmlSqlRow: #{ex.backtrace.join("\n\t")}"
          end
        end
      else
        _run
      end
    end
    
    private
    
    def _run
      @running = true
      @stmt.execute.each do |r|
        @row = r
        @on_new_vector_proc.each_value do |proc|
          proc.call(self)
        end
      end
    end
  end # OmlSqlRow


end

if $0 == __FILE__

  require 'omf-common/oml/oml_table'
  ep = OMF::Common::OML::OmlSqlSource.new('brooklynDemo.sq3')
  ep.on_new_stream() do |s|
    puts ">>>>>>>>>>>> New stream #{s.stream_name}: #{s.names.join(', ')}"
    case s.stream_name
    when 'wimaxmonitor_wimaxstatus'
      select = [:oml_ts_server, :sender_hostname, :frequency, :signal, :rssi, :cinr, :avg_tx_pw]
    when 'GPSlogger_gps_data'
      select = [:oml_ts_server, :oml_sender_id, :lat, :lon]
    end

    s.on_new_vector() do |v|
      puts "New vector(#{s.stream_name}): #{v.select(*select).join('|')}"      
    end
  end
  ep.run()

end

