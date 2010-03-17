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
  module ExperimentController
    module OML

      # An AREL engine which uses the OMF result service
      #
      class ArelResultAdapter < MObject
        include ActiveRecord::ConnectionAdapters::Quoting
      
        FIX_TYPES = {
          'real' => 'float'
        }
        
        def adapter_name
          "OmlResultAdapter"
        end
      
        def columns(tbl_name, log_msg)
          mstream = Table[tbl_name].mstream
          mstream.columns.collect do |name, opts|
            type = opts[:type].downcase
            ctype = FIX_TYPES[type] || type
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
          url = OConfig.RESULT_SERVICE
          #puts "RESULT_URI: #{url}"
          url = url + "/queryDatabase?format=csv&query=#{URI.escape(sql)}&expID=#{Experiment.ID}"
          #puts "SERVICE_URI: #{url}"
          resp = NodeHandler.service_call(url, "Can't query result service")
          rows = []
          resp.body.each_line do |l|
            ri = l.strip.split(';')      
            ro = []
            ri.each_index do |i|
              ro << type_cast_procs[i].call(ri[i])
            end
            rows << ro
          end
          #puts "==> READ RESULT: #{rows.inspect}"
          puts "==> READ RESULT #: #{rows.length}"
          Arel::Array.new(rows, relation.attributes)
        end
        
        def readXXX(relation)
          sql = relation.to_sql
          debug("SQL: #{sql}")
          url = OConfig.RESULT_SERVICE
          #puts "RESULT_URI: #{url}"
          url = url + "/queryDatabase?format=csv&query=#{URI.escape(sql)}&expID=#{Experiment.ID}"
          #puts "SERVICE_URI: #{url}"
          resp = NodeHandler.service_call(url, "Can't query result service")

          rows = []
          resp.body.each_line do |l|
            rows << l.strip.split(';')      
          end
          
          #puts "READ: #{rows}"
          Arel::Array.new(rows, relation.attributes)
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
      end
      Arel::Table.engine = ArelResultAdapter.new
      
      #
      # This class describes ...
      #
      class Table < Arel::Table
        @@instances = {}
        
        def self.[](name)
          @@instances[name]          
        end
        
        attr_reader :mstream
        
        def initialize(mstream, opts = {})
          super(mstream.tableName, opts)
          @mstream = mstream
          @@instances[name] = self
        end
      end # Table
    
    end # module OML
  end # module ExperimentController
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

