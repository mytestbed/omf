
require 'sqlite3'

require 'omf-common/mobject'
require 'omf-oml/endpoint'
require 'omf-oml/tuple'
require 'omf-oml/sql_row'

module OMF::OML
        
  # This class fetches the content of an sqlite3 database and serves it as multiple 
  # OML streams. 
  #
  # After creating the object, the @run@ method needs to be called to 
  # start producing the streams.
  #
  class OmlSqlSource < MObject
    
    # +opts+ - passed on to the +report_new_table+ method.
    #
    def initialize(db_file, opts = {})
      raise "Can't find database '#{db_file}'" unless File.readable?(db_file)
      @db = SQLite3::Database.new(db_file)
      @running = false
      @on_new_stream_procs = {}
      @tables = {}
      @table_opts = opts
    end
    
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
    
    
    # def report_new_stream(stream)
      # @on_new_stream_procs.each_value do |proc|
        # proc.call(stream)
      # end
    # end
    
    # Start checking the database for tables and create a new stream 
    # by calling the internal +report_new_table+ method. 
    #
    # NOTE: The database is immediately and only once checked for tables.
    # Any tables created later is not detected right now. Maybe we should 
    # change that in the future.
    #
    def run()
      # first find tables
      @db.execute( "SELECT * FROM sqlite_master WHERE type='table';") do |r|
        table = r[1]
        report_new_table(table, @table_opts) unless table.start_with?('_')
      end
    end
    
    protected
    
    # THis method is being called for every table detected in the database.
    # It creates a new +OmlSqlRow+ object with +opts+ as the only argument.
    # The tables is then streamed as a tuple stream.
    # After the stream has been created, each block registered with 
    # +on_new_stream+ is then called with the new stream as its single
    # argument.
    #
    def report_new_table(table_name, opts = {})
      t = @tables[table_name] = OmlSqlRow.new(table_name, @db, self, opts)
      @on_new_stream_procs.each_value do |proc|
        proc.call(t)
      end
    end
    
  end
  


end

if $0 == __FILE__

  require 'omf-oml/table'
  ep = OMF::OML::OmlSqlSource.new('brooklynDemo.sq3')
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

