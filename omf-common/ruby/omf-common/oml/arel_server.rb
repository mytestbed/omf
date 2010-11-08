require 'rubygems'
require 'rexml/document'
require 'time'
require 'logger'

require 'arel'
require 'arel/engines/sql/relations/table'

module OML
  module Arel
    module XML
      module Server

        class Query
          
          def self.parse(xmls, repoFactory = RepositoryFactory.new, logger = Logger.new(STDOUT))
            doc = REXML::Document.new(xmls)
            root = doc.root
            unless root.name == 'query'
              raise "XML fragment needs to start with 'query' but does start with '#{root.name}"
            end
            q = self.new(root, repoFactory, logger)
            #q.relation
          end
          
          def initialize(queryEl, repoFactory, logger)
            @queryEl = queryEl
            @repoFactory = repoFactory || RepositoryFactory.new
            @logger = logger || Logger.new(STDOUT)
            @tables = {}
            @lastRel = nil
            queryEl.children.each do |el|
              @lastRel = parse_el(el, @lastRel)
            end            
          end
          
          def each(&block)
            relation.each(&block)
          end

          def relation
            raise "No query defined, yet" unless @lastRel
            @lastRel
          end
          
          # Requested format for result. Default is 'xml'
          def rformat
            @queryEl.attributes['rformat'] || 'xml'
          end

          def parse_el(el, lastRel)
            if (el.kind_of? REXML::Text)
              # skip
              return lastRel
            end
            args = parse_args(el)
            @logger.debug "CHILD #{el.name}"
            # keep the last table for this level to be used 
            # to create proper columns.
            # NOTE: This is not fool-proof but we need columns
            # to later resolve the column type.
            #
            name = el.name.downcase
            if lastRel.nil?
              case name
              when /repository/
                lastRel = parse_repository(el)
              when /col/
                lastRel = parse_column(el)
              else
                raise "Need to start with 'table', or 'col' declaration, but does with '#{name}'"
              end
            elsif name == 'table'
              lastRel = @repository.table_from_xml(el)
            elsif name == 'project'
              # turn all arguments into proper columns
              cols = convert_to_cols(args)
              lastRel = lastRel.project(*cols)              
            elsif lastRel.kind_of?(::Arel::Table) && name  == 'as'
              # keep track of all created tables
              lastRel = lastRel.as(*args)
              @repository.add_table(args[0], lastRel)
            else
              lastRel = lastRel.send(name, *args)
            end
            lastRel
          end
          
          def parse_repository(el)
            @repository = @repoFactory.create_from_xml(el, @logger)
          end
          
          
          # Return the arguments defined in @parentEl as array
          def parse_args(parentEl)
            args = []
            parentEl.children.each do |el|
              next if (el.kind_of? REXML::Text)
              unless el.name == 'arg'
                raise "Expected argument definition but got element '#{el.name}"
              end
              args << parse_arg(el)
            end
            args
          end
          
          # Return the arguments defined in @parentEl as array
          def parse_arg(pel)
            res = nil
            pel.children.each do |el|
              if (el.kind_of? REXML::Text)
                val = el.value
                next if val.strip.empty? # skip text between els
                return parse_arg_primitive(pel, val)
              else
                res = parse_el(el, res)
              end
            end
            res
          end
          
          def parse_arg_primitive(pel, value)
            type = pel.attributes['type'] || 'string'
            case type
            when /string/
              value
            when /boolean/
              value.downcase == 'true' || value == '1'
            when /decimal/
              value.to_i
            when /double/
              value.to_f
            when /dateTime/
              Time.xmlschema
            else
              raise "Unknown arg type '#{type}"
            end
          end
          
          def convert_to_cols(args)
            args.collect do |arg|
              if arg.kind_of? String
                table = @repository.get_first_table()
                raise "Unknown table for column '#{arg}'" unless table
                table[arg]
              else
                arg
              end
            end
          end
          
          # <col name='oml_sender_id' table='iperf_TCP_Info'/>
          def parse_column(el)
            unless colName = el.attributes['name']
              raise "Missing 'name' attribute for 'col' element"
            end
            unless tblName = el.attributes['table']
              raise "Missing 'table' attribute for col '#{colName}'"
            end
            unless table = @repository.table(tblName)
              raise "Unknown table name '#{tblName}'"
            end
            unless col = table[colName]
              raise "Unknown column '#{colName}'"
            end
            if colAlias = el.attributes['alias']
              col = col.as(colAlias)
            end
            col
          end
          
        end # Query
        
        class RepositoryFactory
          
          def initialize(repoClass, opts = {})
            @repoClass = repoClass
            @opts = opts
          end

          def create_from_xml(el, logger)
            @repoClass.new(el, @opts, logger)
          end
          
        end # RepositoryFactory
        
        class AbstractRepository < MObject

          def initialize(repoEl = nil, opts = {}, logger = nil)
            @opts = opts
            @logger = logger || Logger.new(STDOUT)
            @tables = {}
            @firstTable = nil
          end
          
          def table(name)
            unless t = @tables[name] 
              t = add_table(name, Table(name))
            end
            t
          end
          
          # Return a table if there is only one known
          def get_first_table()
            @firstTable
          end

          def add_table(name, table)
            @firstTable ||= table
            @tables[name] = table 
            table
          end
          
          def table_from_xml(el)
            tname = el.attributes['tname']
            #table = @tables[tname] ||= Table(tname)
            table = table(tname)
            #table = Table(tname)
            unless table.table_exists?
              raise "Unknown table '#{tname}'"
            end
            if (aliaz = el.attributes['alias'])
              table = @tables[aliaz] ||= table.as(aliaz)
              #table = table.as(aliaz)
            end
            table
          end
        end # AbstractRepository
        
        class SqliteRepository < AbstractRepository
          def initialize(repoEl, opts, logger = nil)
            super
            @name = repoEl.attributes['name']
            raise "Missing 'name' attribute for repository" unless @name
            
            require 'active_record'
            ActiveRecord::Base.logger = @logger
            db_dir = @opts[:db_dir] || @opts['db_dir'] || '.'
            db_file = "#{db_dir}/#{@name}.sq3" # "omf-common/examples/web/test.sq3"
            db_config = {
                :adapter  => 'sqlite3',
                :database => db_file,
                :timeout  => 5000
            }
            debug "Connecting to database '#{db_file}'"
            ActiveRecord::Base.establish_connection(db_config)
            ::Arel::Table.engine = ::Arel::Sql::Engine.new(ActiveRecord::Base)
          end
        end # SqliteRepository
      
      end # Server
    end # XML
  end # Arel
end # OML


module Arel
  class Table
    def options()
      @options || {}
    end
  end
end


def test_arel_server()
  s2 = %{
    <query>
      <repository name='test'/>
      <table tname='iperf_TCP_Info'/>
      <as>
        <arg type='string'>t</arg>
      </as>
      <project>
        <arg>
          <col name='oml_sender_id' alias='foo' table='t'/>
        </arg>
        <arg>
          <col name='oml_ts_server' table='t'/>
          <as>
            <arg type='string'>goo</arg>
          </as>
        </arg>
        <arg><col name='Bandwidth_avg' table='t'/></arg>
      </project>
      <where>
        <arg>
          <col name='oml_sender_id' table='t'/>
          <eq>
            <arg type='decimal'> 2</arg>
          </eq>
        </arg>
      </where>
    </query>
  }
  
#  mc = repo[:mediacontent]
#  mc2 = mc.alias
#  accessed = mc2.where(mc2[:status].eq('Accessed')).project(:oml_ts_server, :name)
#  q = mc.project(:name).join(accessed).on(mc[:name].eq(mc2[:name]))
  
  s3 = %{
  <query>
    <repository name='prefetching_4'/>
    <table tname='mediacontent'/>
    <project>
      <arg type='string'>name</arg>
    </project>
    <join>
      <arg>
        <repository name='prefetching_4'/>
        <table tname='mediacontent' talias='mediacontent1'/>
        <where>
          <arg>
            <col name='status' table='mediacontent' talias='mediacontent1'/>
            <eq>
              <arg type='string'>Accessed</arg>
            </eq>
          </arg>
        </where>
        <project>
          <arg type='string'>oml_ts_server</arg>
          <arg type='string'>name</arg>
        </project>
      </arg>
    </join>
    <on>
      <arg>
        <col name='name' table='mediacontent'/>
        <eq>
          <arg>
            <col name='name' table='mediacontent' talias='mediacontent1'/>
          </arg>
        </eq>
      </arg>
    </on>
  </query>
  }
  
  factory = OML::Arel::XML::Server::RepositoryFactory.new(
                OML::Arel::XML::Server::SqliteRepository, 
                {:db_dir => 'omf-common/test'}
            )
  first = true
  types = []
  OML::Arel::XML::Server::Query.parse(s3, factory).relation.take(10).each do |r|
    if (first)
      r.relation.attributes.each do |a| 
        name = a.alias || a.name
        type = a.column.sql_type
        types << "#{name}:#{type}"
      end
      first = false
      puts types.inspect
    end
    puts r.tuple.inspect
  end
  puts "QUERY: done"
end

if $0 == __FILE__
  test_arel_server
end

