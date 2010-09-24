#
# Copyright (c) 2009 National ICT Australia (NICTA), Australia
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
# = oml_arel.rb
#
# == Description
#
# This file provides support for querying OML results using the AREL library.
#




# Monkey patching Array to support the 'active_record' library
#
unless Array.respond_to? :extract_options!
  class Array #:nodoc:
    # Method added in Rails rev 7217
    def extract_options!
      last.is_a?(::Hash) ? pop : {}
    end unless defined? Array.new.extract_options!
  end
end

require 'arel'
require 'active_record'
require 'active_record/connection_adapters/abstract/schema_definitions'
require 'active_record/connection_adapters/abstract/quoting'
require 'uri'


module OMF
  module Common
    module OML

      # An AREL engine which delegates the actual query to a provided proc.
      #
      # Before using the Arel framework, an engine needs to be registered. 
      #
      #    Arel::Table.engine = ArelResultAdapter.new(&queryProc)
      #
      # where 'queryProc' takes an SQL query as an argument and returns the result as a table,
      # or more Ruby specific as an array of rows, where each row is an array of all its column
      # values.
      #
      # Example 'queryProc' calling the OML result service looks like:
      #
      #        do |sql|
      #          url = OConfig.RESULT_SERVICE
      #          url = url + "/queryDatabase?format=csv&query=#{URI.escape(sql)}&expID=#{Experiment.ID}"
      #          resp = NodeHandler.service_call(url, "Can't query result service")
      #          rows = []
      #          resp.body.each_line do |l|
      #            rows << l.strip.split(';')
      #          end
      #          rows
      #        end
      #
      #
      class ArelResultAdapter < MObject
        include ActiveRecord::ConnectionAdapters::Quoting
      
        OVERRIDE_TYPES = {
          'real' => 'float'
        }
        
        
        def initialize(override_types = OVERRIDE_TYPES, &query_proc)
          @queryProc = query_proc
          @overrideTypes = override_types
        end
        
        def adapter_name
          "OmlResultAdapter"
        end
      
        def columns(tbl_name, log_msg)
          Table[tbl_name].columns.collect do |name, opts|
            type = opts[:type].downcase
            ctype = @fixTypes[type] || type
            #col = ::ActiveRecord::ConnectionAdapters::Column.new(name, nil, ctype)
            col = Column.new(name, nil, ctype)
            #puts ">>> TYPE #{type}:#{ctype}:#{col.type}"
            col
          end
        end
      
        def read(relation)
          sql = relation.to_sql
      #    puts "READ: #{sql}"
      #    puts "   READ_REL_CLASS: #{relation.class}"
          table = relation
          while table.respond_to? :relation
            table = table.relation
          end
      #    puts "   READ_TABLE_CLASS: #{table.class}"
      
      #    puts "   READ_REL: #{relation.inspect}"
          type_cast_procs = relation.attributes.collect do |a| 
      #      puts "READ_ATTR: #{a.class}" 
            if a.kind_of? Arel::Attribute
      #        puts "  READ_ATT_NAME: #{a.name}"
      #        puts "  READ_ATT_ALIAS: #{a.alias}"
              a.column.type_cast_proc
            elsif a.kind_of? Arel::Value
              a2 = table.attributes.find do |at| at.named?(a.value) end
              if (a2)
                a2.column.type_cast_proc
              else
                warn("Can't find attribute for '#{a.value}'")
                lambda() do |v| v end
              end
      #        puts "   READ_VALUE: #{a2}"
            end
          end
      #    puts "==> READ_ATTRSSS: #{attrs.inspect}"
      
          debug("SQL: #{sql}")
          rows = []
          @queryProc.call(sql).each do |row|
            r = []
            row.each_with_index do |col, i|
              r << type_cast_procs[i].call(col)
            end
            rows << r
          end
          #puts "==> READ RESULT: #{rows.inspect}"
          puts "==> READ RESULT #: #{rows.length}"
          Arel::Array.new(rows, relation.attributes)
        end
        
        def connection()
          self
        end
              
        def method_missing(method, *args, &block)
          error "Missing method: #{method} <#{args.join('#')}> <#{args.collect do |a| a.class.to_s end.join('#')}>"
        end
      end # OmlResultAdapter
      
      class Column < ::ActiveRecord::ConnectionAdapters::Column
        def type_cast_proc()
          case type
            when :string    then lambda() do |v| v end
            when :text      then lambda() do |v| v end
            when :integer   then lambda() do |v| v.to_i rescue v ? 1 : 0 end
            when :float     then lambda() do |v| v.to_f end
            when :decimal   then lambda() do |v| self.class.v_to_decimal(v) end
            when :datetime  then lambda() do |v| self.class.string_to_time(v) end
            when :timestamp then lambda() do |v| self.class.string_to_time(v) end
            when :time      then lambda() do |v| self.class.string_to_dummy_time(v) end
            when :date      then lambda() do |v| self.class.string_to_date(v) end
            when :binary    then lambda() do |v| self.class.binary_to_string(v) end
            when :boolean   then lambda() do |v| self.class.v_to_boolean(v) end
            else lambda() do |v| v end
          end
        end
        
        def initialize(name, default, sql_type = nil, null = true)
          super(name.to_s, default, sql_type.to_s, null)
        end
      end
      
      #Arel::Table.engine = ArelResultAdapter.new
      
      #
      # This class describes ...
      #
      # Columns:
#                cols['oml_sender_id'] = {:type => 'INTEGER'}
#          cols['oml_seq'] = {:type => 'INTEGER'}
#          cols['oml_ts_client'] = {:type => 'REAL'}
#          cols['oml_ts_server'] = {:type => 'REAL'}
#          if @filters.size > 0
#            @filters.each do |f|
#              cols.merge!(f.columns)              
#            end

      class Table < Arel::Table
        @@instances = {}
        
        def self.[](name)
          @@instances[name.to_sym]          
        end
        
        attr_reader :columns
        
        #          mstream = Table[tbl_name].mstream
        #  mstream.columns.collect do |name, opts|
        # mstream.tableName

        def initialize(tableName, columns, opts = {})
          #super(tableName, opts)
          initialize_override(tableName, opts)
          @columns = columns
          @@instances[tableName.to_sym] = self
        end
        
        private
        
        # this is a duplicate of the super classes initialize function
        # which insists in loading the SQL compiler in a very specific way
        # which causes problems.
        #
        def initialize_override(name, options = {})
          @name = name.to_s
          @table_exists = nil
          @table_alias = nil
          @christener = Arel::Sql::Christener.new
          @attributes = nil
          @matching_attributes = nil
    
          if options.is_a?(Hash)
            @options = options
            @engine = options[:engine] || Table.engine
    
            if options[:as]
              as = options[:as].to_s
              @table_alias = as unless as == @name
            end
          else
            @engine = options # Table.new('foo', engine)
          end
    
#          if @engine.connection
#            begin
#              require "arel/engines/sql/compilers/#{@engine.adapter_name.downcase}_compiler"
#            rescue LoadError
#              begin
#                # try to load an externally defined compiler, in case this adapter has defined the compiler on its own.
#                require "#{@engine.adapter_name.downcase}/arel_compiler"
#              rescue LoadError
#                raise "#{@engine.adapter_name} is not supported by Arel."
#              end
#            end
#    
#            @@tables ||= engine.connection.tables
#          end

        end
      end # Table
    
    end # module OML
  end # module Common
end # OMF

# Monkey patch Row to return type cast row as well
module Arel
  class Row
    def type_cast()
      #puts "ROW: #{self.inspect}"
      #puts "TUPLE: #{tuple}:#{tuple.class}"
      r = []
      tuple.each_index do |i|
        raw = tuple[i]
        attr = relation.attribute_names[i]
        r << attr.type_cast(raw)
      end
      r
    end
  end
end

