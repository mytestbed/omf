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
# = graph_queryresult.rb
#
# == Description
#
# This class describes the return to a graph query as returned by +GraphQuery#execute+.
#

module OMF
  module EC
    module Graph
      class GraphQueryResult < MObject
        attr_reader :result_s, :format

        def initialize(result, format)
          super()
          @result_s = result
          @format = format
        end

        def each_row(&block)
          return nil unless block

          case @format
          when 'csv'
            result_s.each_line do |l|
              block.call(l.split(';'))
            end
          else
            raise UnknownGraphResultFormat(@format)
          end

        end
      end # GraphQueryResult

    end # Graph
  end # EC
end # OMF
