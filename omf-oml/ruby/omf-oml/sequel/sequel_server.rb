require 'rubygems'
require 'rexml/document'
require 'time'
require 'logger'
require 'sequel'

require 'omf-common/mobject'
require 'omf-oml'

module OMF::OML
  module Sequel; end
end

module OMF::OML::Sequel
  module Server

    class Query

      def self.parse(xmls, repoFactory = RepositoryFactory.new, logger = Logger.new(STDOUT))
        if xmls.kind_of? String
          doc = REXML::Document.new(xmls)
          root = doc.root
        else
          root = xmls
        end
        unless root.name == 'query'
          raise "XML fragment needs to start with 'query' but does start with '#{root.name}"
        end
        q = self.new(root, repoFactory, logger)
        q.relation
      end

      def initialize(queryEl, repoFactory, logger)
        @queryEl = queryEl
        @repoFactory = repoFactory || RepositoryFactory.new
        @logger = logger || Logger.new(STDOUT)
        @tables = {}
        @lastRel = nil
        @offset = 0
        @limit = 0
        queryEl.children.each do |el|
          @lastRel = parse_el(el, @lastRel)
        end
        if @limit > 0
          @lastRel = @lastRel.limit(@limit, @offset)
        end
      end

      def each(&block)
        # sel_mgr = relation
        # unless sel_mgr.kind_of? SelectionManager
          # raise "Can only be called on SELECT statement"
        # end
        # puts sel_mgr.engine
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
            lastRel = repo = parse_repository(el)
            @tables = repo.tables
            @logger.debug "Created repository: #{lastRel}"
          else
            raise "Need to start with 'table' declaration, but does with '#{name}'"
          end
        elsif name == 'table'
          lastRel = parse_table(el)
        elsif name == 'project'
          # turn all arguments into proper columns
  #              cols = convert_to_cols(args)
          lastRel = lastRel.select(*args)
  #            elsif lastRel.kind_of?(::Arel::Table) && name  == 'as'
  #              # keep track of all created tables
  #              lastRel = lastRel.alias(*args)
  #              @repository.add_table(args[0], lastRel)
        elsif name == 'skip'
          @offset = args[0].to_i
        elsif name == 'take'
          @limit = args[0].to_i
        else
          @logger.debug "Sending '#{name}' to #{lastRel.class}"
          lastRel = lastRel.send(name, *args)
        end
        @logger.debug "lastRel for <#{el}> is  #{lastRel.class}"
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
        #col = nil
        pel.children.each do |el|
          if (el.kind_of? REXML::Text)
            val = el.value
            next if val.strip.empty? # skip text between els
            return parse_arg_primitive(pel, val)
          else
            name = el.name.downcase
            case name
            when /col/
              res = parse_column(el)
            when /eq/
              if res.nil?
                raise "Missing 'col' definiton before 'eq'."
              end
              p = parse_args(el)
              unless p.length == 1
                raise "'eq' can only hnadle 1 argument, but is '#{p.inspect}'"
              end
              res = {res => p[0]}
            else
              raise "Need to be 'col' declaration, but is '#{name}'"
            end
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
        col = colName
        unless tblName = el.attributes['table']
          raise "Missing 'table' attribute for col '#{colName}'"
        end
        unless @tables.member?(tblName.to_sym)
          raise "Unknown table name '#{tblName}' (#{el})"
        end
        col = "#{tblName}__#{colName}"

        if colAlias = el.attributes['alias']
          col = "#{col}___#{colAlias}"
        end
        col.to_sym
      end

      def parse_table(el)
        unless name = el.attributes['tname']
          raise "Missing 'tname' attribute for 'table' element"
        end
        if talias = el.attributes['talias']
          name = "#{name}___#{talias}"
          @tables << talias.to_sym
        end

        @repository[name.to_sym]
      end

    end # Query

    class RepositoryFactory

      def initialize(opts = {})
        @opts = opts
      end

      def create_from_xml(el, logger)
        name = el ? el.attributes['name'] : nil
        raise "<repository> is missing attribute 'name'" unless name
        create(name, logger)
      end

      def create(database, logger = Logger.new(STDOUT))
        opts = @opts.dup
        if pre = opts[:database_prefix]
          database = pre + database
          opts.delete(:database_prefix)
        end
        if post = opts[:database_postfix]
          database = database + post
          opts.delete(:database_postfix)
        end
        opts[:database] = database
        ::Sequel.connect(opts)
      end

    end # RepositoryFactory
  end # Server
end

module Sequel
  class Dataset
    CLASS2TYPE = {
      TrueClass => 'boolean',
      FalseClass => 'boolean',
      String => 'string',
      Symbol => 'string',
      Fixnum => 'decimal',
      Float => 'double',
      Time => 'dateTime'
    }

    def row_description(row)
      n = naked
      cols = n.columns
      descr = {}
      cols.collect do |cn|
        cv = row[cn]
        descr[cn] = CLASS2TYPE[cv.class]
      end
      descr
    end

    def schema_for_row(row)
      n = naked
      cols = n.columns
      descr = {}
      cols.collect do |cn|
        cv = row[cn]
        {:name => cn, :type => CLASS2TYPE[cv.class]}
      end
    end
  end
end



def test_sequel_server()

  tests = []

  tests <<  %{
    <query>
      <repository name='test'/>
      <table tname='iperf_TCP_Info'/>
      <project>
        <arg><col name='Bandwidth_avg' table='iperf_TCP_Info'/></arg>
      </project>
    </query>
  }

  tests << %{
    <query>
      <repository name='test'/>
      <table tname='iperf_TCP_Info' talias='t'/>
      <project>
        <arg>
          <col name='oml_sender_id' alias='foo' table='t'/>
        </arg>
        <arg>
          <col name='oml_ts_server' table='t' alias='goo'/>
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

#  tests << %{
#    <query>
#      <repository name='prefetching_4'/>
#      <table tname='mediacontent'/>
#      <project>
#        <arg type='string'>name</arg>
#      </project>
#      <join>
#        <arg>
#          <table tname='mediacontent' talias='mediacontent1'/>
#          <where>
#            <arg>
#              <col name='status' table='mediacontent' talias='mediacontent1'/>
#              <eq>
#                <arg type='string'>Accessed</arg>
#              </eq>
#            </arg>
#          </where>
#          <project>
#            <arg type='string'>oml_ts_server</arg>
#            <arg type='string'>name</arg>
#          </project>
#        </arg>
#      </join>
#      <on>
#        <arg>
#          <col name='name' table='mediacontent'/>
#          <eq>
#            <arg>
#              <col name='name' table='mediacontent' talias='mediacontent1'/>
#            </arg>
#          </eq>
#        </arg>
#      </on>
#    </query>
#  }

  factory = OMF::OML::Sequel::Server::RepositoryFactory.new(
              :adapter => 'sqlite',
              :database_prefix => '/Users/max/src/omf_mytestbed_net/omf-common/test/',
              :database_postfix => '.sq3'
            )

  repo = factory.create('test')
  puts repo.tables

  tests.each do |t|
    ds = OMF::OML::Sequel::Server::Query.parse(t, factory)
    puts ds.inspect
    puts ds.columns.inspect
    puts ds.first.inspect
  end

  first = true
  types = []
  ds = OMF::OML::Sequel::Server::Query.parse(tests[1], factory).limit(10)
  ds.each do |r|
    if (first)
      puts ds.row_description(r).inspect
      puts ds.schema_for_row(r).inspect
      #puts (ds.schema_for_row(r).methods - Object.new.methods).sort
#      cols = ds.columns
#      #cols.collect do |c|
#      cols.each do |c|
#        puts "#{c} : #{OML::Sequel::XML::Server::Query::CLASS2TYPE[r[c].class]}"
#      end
      first = false
#      puts types.inspect
    end
    puts r.inspect
  end
  puts "QUERY: done"
end

if $0 == __FILE__
  test_sequel_server
end

