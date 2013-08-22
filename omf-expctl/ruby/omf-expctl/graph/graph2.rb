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
# = graph.rb
#
# == Description
#
# This class describes a graph which can be displayed through the
# web interface or any other defined graph visualizer.
#
gem 'sequel'
gem 'json'
require 'sequel'
require 'json'

module OMF::EC
  module Graph

    class GraphDescription < MObject
      @@gds = {}
      
      def self.create(name = nil)
        if name
          @@gds[name.to_sym] ||= self.new(name)
        else
          self.new("Unknown #{self.object_id}")
        end
      end
      
      # Define text to be shown above the graph
      #
      # @param text
      #
      def postfix(text)
        @postfix = text
      end
      
      # Define the measurement stream to be visualized in 
      # the graph. The optional 'context' parameter defines 
      # the context in which the MS is used in the graph. This 
      # is necessary for graphs, such as 'networks' which need
      # more than one MS to describe the visualization.
      #
      # @param ms_name 
      # @param context
      #
      def ms(ms_name, context = :default)
        unless ms = OMF::EC::OML::MStream[ms_name.to_s]
          legal = Set.new
          OMF::EC::OML::MStream.each {|n, m| legal << m.name }
          raise OEDLIllegalArgumentException.new(:ms, :ms_name, legal.to_a)
        end
        (@ms[context] ||= []) << (msb = MSBuilder.new(@db[ms.tableName.to_sym]))
        msb
      end
      
      # Defines the mapping of columns in the measurement tuples to properties
      # of the visualization.
      #
      # @param mhash Hash of mappings specific to the graph ifentified by 'type'
      def mapping(mhash)
        @mapping = mhash
      end

      def type(gtype)
        @gtype = gtype
      end
      
      def xaxis(props)
        (@axis ||= {})[:x] = props
      end

      def yaxis(props)
        (@axis ||= {})[:y] = props
      end
      
      def caption(text)
        @caption = text
      end
      

      def _report
        info "REPORT:START: #{@name}"
        info "REPORT:TYPE: #{@gtype}"
        info "REPORT:POSTFIX: #{URI.encode(@postfix)}" if @postfix
        @ms.each do |ctxt, a|
          a.each do |ms|
            info "REPORT:MS:#{ctxt}: #{URI.encode(ms.sql)}"
          end
        end
        info "REPORT:MAPPING: #{URI.encode(@mapping.to_json)}"
        if @axis
          info "REPORT:AXIS: #{URI.encode(@axis.to_json)}"
        end
        info "REPORT:CAPTION: #{URI.encode(@caption)}" if @caption        
        info "REPORT:STOP"
      end


      protected
      def initialize(name)
        @name = name
        @ms = {}
        # Create a generic Sequel object which can be used to serialize the query.
        # TODO: Make sure this is generic enough
        @db = Sequel.postgres
        @db.instance_variable_set('@server_version', 90105)
      end

    end # class

    class MSBuilder < MObject
      
      def initialize(data_set)
        @data_set = data_set
      end
      
      def method_missing(symbol, *args, &block)
        debug "Calling #{symbol}::#{args.inspect}"
        res = @data_set.send(symbol, *args, &block)
        if res.is_a? Sequel::Postgres::Dataset
          @data_set = res
          res = self
        end
        debug "Result: #{res.class}"
        res
      end
      
    end # class

  end # module Graph

  module Commands
    #
    # Define a new graph widget showing experiment related measurements to be
    # be used in a LabWiki column.
    #
    # The block is called with an instance of the 'LabWiki::OMFBridge::GraphDescription'
    # class. See that classes' documentation on the methods supported.
    #
    # - name = optional, short/easy to remember name for this graph
    # - &block = a code-block to execute on the newly created graph description
    #
    def defGraph(name = nil, &block)
      gd = OMF::EC::Graph::GraphDescription.create(name)
      block.call(gd)
      gd._report
    end
  end
end # OMF




