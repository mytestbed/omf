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
  module ExperimentController
    module Graph
      module Filter
        module MutipleTimeLines
          
          def self.filter(qres)
            reply = []
            h = {}
            names = []
            names_h = {}
            start_ts = nil
            prev_ts = 0
            qres.each_row do |cols|
              ts = (cols.shift || 0).to_i
              start_ts ||= ts # first
              node = cols.shift
              value = cols.shift
              unless names_h.key?(node)
                # keep track of node names
                names << node
                names_h[node] = true
              end
              if h.key?(node)
                # got another value for +node+, output graph row
                va = names.collect do |n| h[n] end
                unless va.empty?
                  if (ts_d = start_ts - prev_ts) > 0
                    i = 0
                    while ts_d < 1.0 
                      i += 1; ts_d *= 10
                    end
                    ts_s = sprintf("%.#{i}f", start_ts)
                  else
                    ts_s = 0
                  end
                  va.insert(0, ts_s)
                  reply << va
                end
                h = {}
                prev_ts = start_ts
                start_ts = nil
              end
              h[node] = value
            end
            # prepand empty record of size names
            reply.insert(0, [nil] * names.size)
          end
          
        end
      end
    end
  end
end
