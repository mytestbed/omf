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
require 'omf-expctl/graph/graph_query'

module OMF
  module ExperimentController
    module Graph

      class Graph
        @@instances = []
      
        attr_accessor :name

        def initialize(uri = nil, &block)
          @@instances << self
          @name = 'Graph #{@@instances.length}'
          block.call(self)
        end

        # define the query to perform on the 'result' service to obtain
        # the data to show on this graph
        #
        def query(&block)
          @query = GraphQuery.new(block) 
        end

        # Define a filter to run over the query result to further process
        # the array of rows returned by +query+
        #
        def filter(klass = nil, &block)
          @filterClass = klass
          @filterBlock = block
        end
        
        # Execute query on result service, run optional filter on result, and return result as string
        #
        def run_query()
          return nil unless @query
          
          gres = @query.execute()
          if @filterClass 
            fres = @filterClass.filter(gres)
            res = fres.kind_of?(Array) ? fres.join("\n") : fres.to_s
          elsif @filterBlock 
            fres = @filterBlock.call(gres)
            res = fres.kind_of?(Array) ? fres.join("\n") : fres.to_s
          else
            res = fres.result_s
          end
          res
        end
      end
    
    end # module Graph
  end # module ExperimentController
end # OMF


