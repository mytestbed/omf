require 'rexml/document'
#require 'rexml/element'
require 'time'
require 'omf-common/mobject'
require 'time'


module OMF
  module Common
    module OML
      module Arel
        class ArelException < Exception; end
        class ArelRemoteException < ArelException; end

        class Serializable < MObject
          
          protected
          
          CLASS2TYPE = {
            TrueClass => 'boolean',
            FalseClass => 'boolean',
            String => 'string',
            Symbol => 'string',            
            Fixnum => 'decimal',
            Float => 'double',
            Time => 'dateTime'
          }

          def _args_to_xml(args, parent_el)
            args.each do |arg|
              ael = parent_el.add_element('arg') #REXML::Element.new('arg')
              if arg.kind_of?(Serializable)
                arg.to_xml(ael)
              else
                type = CLASS2TYPE[arg.class]
                unless type
                  raise "Unknown type '#{arg.class}'"
                end
                ael.add_attribute("type", type)
                if arg.kind_of? Time
                  arg = arg.xmlschema
                end
                ael.text = arg.to_s
              end
              
            end
          end
        end
        
        class Repository
          
          @@serviceAdaptorClass = nil
          
          def self.ServiceAdaptor=(klass)
            @@serviceAdaptorClass = klass
          end
         
          def initialize(args = {}, adaptor = nil)
            @args = args
            @adaptor = adaptor
            @tables = {}
          end
          
          def [](table_name)
            @tables[table_name] || Table.new(self, table_name)
          end
          
          def to_xml(parent_el = nil)
            unless parent_el
              parent_el = REXML::Element.new('query')
            end
            el = REXML::Element.new('repository')
            @args.each do |key, value|
              el.add_attribute(key.to_s, value)
            end
            parent_el.add_element(el)
            parent_el
          end

          def _each(lastRel, &block)
            adaptor = @adaptor || @@serviceAdaptorClass.create()
            adaptor.each(self, lastRel, &block)
            #_serialize()
          end
          
          # :nodoc
          def register_table(table, name)
            @tables[name] = table
          end
        end
        
        class Relation < Serializable
          
          [:from, :group, :having, :join, :order, :on,
            :project, :where, :skip, :take, :lock
          ].each  do |op|
            class_eval <<-OPERATION, __FILE__, __LINE__
              def #{op}(*args)
                Relation.new(:#{op}, args, self)
              end
            OPERATION
          end

          def each(&block)
            _each(self, &block)
          end
          
          def to_xml(parent_el = nil)
            #puts "XML: #{self}::#{@relation}::#{parent_el.nil?}"
            parent_el = @relation.to_xml(parent_el) if @relation
            el = REXML::Element.new(@op.to_s)
            _args_to_xml(@args, el)
            #el.add_attribute("name", "#{@mdef}")
            parent_el.add_element(el) if parent_el
            parent_el || el
          end
          
          def initialize(op, args = {}, relation = nil)
            super()
            @op = op
            @args = args
            @relation = relation
          end
          
          def _each(lastRel, &block)
            @relation._each(lastRel, &block)
          end
          

          protected
          def _serialize()
            el = REXML::Element.new('query')
            to_xml(el)
            el
          end
        end # Relation
        
        class Table < Relation
          attr_reader :tname, :talias
          
          def [](col_name)
            @columns[col_name] ||= Column.new(col_name, self)
          end
          
          def as(table_alias)
            Table.new(@repository, tname, table_alias)
          end

          def alias()
            table_alias = "#{tname}#{@aliasCnt += 1}"
            Table.new(@repository, tname, table_alias)
          end

          def to_xml(parent_el = nil)
            parent_el = @repository.to_xml(parent_el)
            el = REXML::Element.new('table')
            el.add_attribute("tname", @tname)
            el.add_attribute("talias", @talias) if @talias            
            parent_el.add_element(el) if parent_el
            parent_el || el
          end
          
          def _each(lastRel, &block)
            @repository._each(lastRel, &block)
          end
          

          protected
          def initialize(repository, name, aliaz = nil)
            super 'table'
            @repository = repository
            @tname = name.to_s             
            @talias = aliaz.to_s if aliaz
            @columns = {}
            @aliasCnt = 0
            repository.register_table(self, @talias || @talias)
          end
        end # Table
        
        class Predicate < Serializable
          
          [
            :eq, :eq_any, :eq_all, :not_eq, :not_eq_any, :not_eq_all, :lt, :lt_any,
            :lt_all, :lteq, :lteq_any, :lteq_all, :gt, :gt_any, :gt_all, :gteq,
            :gteq_any, :gteq_all, :matches, :matches_any, :matches_all, :not_matches,
            :not_matches_any, :not_matches_all, :in, :in_any, :in_all, :not_in,
            :not_in_any, :not_in_all
          ].each do |pred|
            class_eval <<-OPERATION, __FILE__, __LINE__
              def #{pred}(*args)
                Predicate.new(:#{pred}, args, self)
              end
            OPERATION
          end
          
          def to_xml(parent_el = nil)
            #puts "XML: #{self}::#{@successor}"
            parent_el = @successor.to_xml(parent_el) if @successor
            el = REXML::Element.new(@name)
            _args_to_xml(@args, el)
            #el.add_attribute("name", "#{@mdef}")
            parent_el.add_element(el) if parent_el
            parent_el || el
          end
          
          def initialize(name, args = [], successor = nil)
            @name = name.to_s
            @args = args
            @successor = successor
          end
        end # Predicate
        
        class Column < Predicate
          
          [:count, :distinct, :sum, :max, :min, :avg, :asc, :desc].each do |op|
            class_eval <<-OPERATION, __FILE__, __LINE__
              def #{op}()
                Predicate.new(:#{op}, [], self)
              end
            OPERATION
          end
          
          def as(aliaz)
            Column.new(@cname, @table, aliaz)
          end
          
          def initialize(name, table, aliaz = nil)
            super 'col'
            @cname = name.to_s
            @table = table
            @aliaz = aliaz.to_s if aliaz
          end
          
          def to_xml(parent_el = nil)
            parent_el = @successor.to_xml(parent_el) if @successor
            el = REXML::Element.new(@name.to_s)
            el.add_attribute("name", @cname.to_s)
            tname = @table.tname.to_s
            el.add_attribute("table", tname)
            talias = @table.talias.to_s
            if !talias.empty? && talias != tname
              el.add_attribute("talias", talias)
            end
            el.add_attribute("alias", @aliaz.to_s) if @aliaz
            parent_el.add_element(el) if parent_el
            parent_el || el
          end
          
          # Return underlying table object. Use with care
          def _table()
            @table
          end
          
        end # Column
        
        # This class takes a query, defined by the last relation, serializes
        # it, calls a remote query service provider and finally returns the
        # result to the caller.
        #
        class HttpServiceAdaptor < MObject
          def self.create()
            self.new
          end
          
          def initialize(url)
            require 'net/http'  
            require 'uri'            

            @url = URI.parse(url)
          end          
          
          def each(repository, lastRel, &block)
            req = REXML::Element.new('request')
            req.add_namespace('http://schema.mytestbed.net/am/result/2/')
            id = self.hash.to_s
            req.add_attribute('id', id)
            result = req.add_element('result')
            result.add_element('format').text = 'xml'
            lastRel.to_xml(req.add_element('query'))
            puts req.to_s
            resp = Net::HTTP.new(@url.host, @url.port).post(@url.path, req.to_s)
            if (resp.code != 200) 
              raise ArelRemoteException, resp.body
            end
            puts resp.body
            unless (ct = resp['Content-Type']) != 'text/html'
              raise "Server returns result in unknown mime type '#{ct}'"
            end
            parse_service_reply(resp.body, &block) 
          end
          
          private
          def parse_service_reply(reply, &block)
            doc = REXML::Document.new(reply)
            root = doc.root
            unless root.name == 'response'
              raise "XML fragment needs to start with 'response' but does start with '#{root.name}"
            end
            
            row = nil
            root.children.each do |el|
              case el.name
              when /schema/
                row = Row.new(el)
              when /rows/
                parse_rows(el, row, &block)
              else
                raise "Unknown element '#{el.name}' in reply."
              end
            end            
            
          end
          

          def parse_rows(rows_el, row, &block)
            rows_el.children.each do |row_el|
              unless row_el.name == 'r'
                raise "Expected element 'r', but found '#{row_el.name}'"
              end
              row.reset
              row_el.children.each do |col_el|
                unless col_el.name == 'c'
                  raise "Expected element 'c', but found '#{col_el.name}'"
                end
                row << col_el.text            
              end
              block.call(row)
            end            
          end
        end # ServiceAdaptor
          
        class Row < MObject
          attr_reader :tuple
          attr_reader :schema
          
          def [](name)
            i = @name2schemaID[name.to_sym]
            i >= 0 ? @tuple[i] : nil
          end
          
          def initialize(schema_el)
            parse_schema(schema_el)
            
            @tuple = []
            reset()
          end
          
          def reset()
            @index = 0
            #@tuple.clear
            @tuple = []
          end
          
          def <<(value)
            @tuple << @schema[@index].type_cast(value)
            @index += 1
            value
          end
          
          private 
          def parse_schema(schema_el)
            @name2schemaID = {}
            i = 0
            @schema = schema_el.children.collect do |col_el|
              unless col_el.name == 'col'
                raise "Expected element 'col', but found '#{col_el.name}'"
              end
              c_name = col_el.attributes['name']
              c_type = col_el.attributes['type']
              @name2schemaID[c_name.to_sym] = i
              i += 1
              ColSchema.new(c_name, c_type)
            end
          end
        end # Row

        # Describes a column in a result tuple
        #
        class ColSchema < MObject
          attr_reader :name
          attr_reader :type
          attr_reader :sql_type
          
          def initialize(name, sql_type)
            @name = name
            @sql_type = sql_type.downcase.to_sym
            set_type_cast_proc(@sql_type)
          end
          
          def type_cast(value)
            @caster.call(value)
          end
        
          private
          def set_type_cast_proc(type)
            @type = :string
            case type
            when :string, :text
              @caster = lambda() do |v| v end
             when :integer, :decimal
               @caster = lambda() do |v| v.to_i rescue v ? 1 : 0 end
               @type = :integer
             when :float, :real, :double
               @caster = lambda() do |v| v.to_f end
               @type = :float
             when :datetime, :timestamp, :time
               @caster = lambda() do |v| Time.xmlschema(v) rescue nil end
               @type = :time
#             when :binary
#               @caster = lambda() do |v| self.class.binary_to_string(v) end
             when :boolean
               @caster = lambda() do |v| v == 1 || v.downcase == 'true' end
               @type = :boolean
             else 
               warn "Unknown sql_type '#{type}'"
               @caster = lambda() do |v| v end
               @type = :unknown
            end
          end
          
        end # Col

      end # Arel
    end # OML
  end # Common
end # OMF

if $0 == __FILE__
  adaptor = OMF::Common::OML::Arel::HttpServiceAdaptor.new('http://localhost:5053/result2/query') 
  opts = {:name => 'test'}
  repo = OMF::Common::OML::Arel::Repository.new(opts, adaptor) 
  t1 = repo[:foo]
  t1[:c1]
  puts t1.project(:c1, :c2).to_xml
  puts t1.project(t1[:c1], t1[:c2]).to_xml
  puts t1.as(:tB).project(t1[:c1].as(:cA), t1.as(:tA)[:c2]).to_xml
  puts t1.project(:c1).where(t1[:c1].eq(Time.now)).to_xml
  
  t = repo[:iperf_TCP_Info].as(:t)
  p = t.project(t[:oml_sender_id].as(:foo), t[:oml_ts_server].as(:goo), t[:Bandwidth_avg])
  p.where(t[:oml_sender_id].eq(2)).each do |r|
    puts r.tuple.inspect
  end
  puts "Done"
end
