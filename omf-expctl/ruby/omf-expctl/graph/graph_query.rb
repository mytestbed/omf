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
# = graph_query.rb
#
# == Description
#
# This class describes a query on the experiments measurement streams to 
# obtain a data set to be displayed in the associated graph.
#
require 'graph_query_result'

module OMF
  module ExperimentController
    module Graph

      class GraphQueryException < Exception; end
        
      class GraphQuery < MObject
        def initialize(block)
          super()
          block.call(self)
        end
        
        def select=(select)
          if from.kind_of? Array
            @select = select.join(',')
          else
            @select = select.to_s
          end
          reset
        end

        def from=(from)
          if from.kind_of? Array
            @from = from.join(',')
          else
            @from = from.to_s
          end
          reset
        end
        
        def format(format)
          @format = format
          reset()
        end
        
        # Executes the query associated with this object and return a GraphQueryResult
        #
        def execute()
          unless @serviceURL
            query = queryTerm()
            expID ||= Experiment.ID
            resultURL ||= OConfig[:ec_config][:result][:url]
            @serviceURL = "http://#{@resultURL}/result/queryDatabase?expID=#{expID}&format=#{@format}&query=#{URI.escape(query)}"
          end
          res = NodeHandler.service_call(url, "Can't query results '#{@serviceURL}'")
          GraphQueryResult.new(res, @format)
        end
        
        private
        
        def reset()
          @serviceURL= nil
        end
        
        def queryTerm
          "select #{select} from #{@from};"
        end
      end
      
      
    
    end # module Graph
  end # module ExperimentController
end # OMF
