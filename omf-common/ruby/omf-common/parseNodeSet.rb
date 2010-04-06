#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
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
require 'omf-common/mobject'

class ParseNodeSet < MObject

    def safeEval(str)
      begin
    res = nil
  Thread.new() {
    $SAFE = 4
    res = eval(str)
  }.join
      rescue Exception => ex
        puts "Exception: #{ex}"
      end
      res
    end

    def parseNodeSetArray(ap)
       nodeSet = Array.new
       if ( !ap.kind_of?(Array) )
         raise "Type error"
       end
       if (ap.length == 2 \
           && ap[0].kind_of?(Integer) || ap[0].kind_of?(Range) \
           && ap[1].kind_of?(Integer) || ap[1].kind_of?(Range))
         nodeSet.concat(parseNodeSet(ap[0], ap[1]))
       else
         ap.each {|a| nodeSet.concat(parseNodeSetArray(a)) }
       end
       return nodeSet
    end

    def parseNodeSet(x, y)
      nlist = Array.new
      if (x.kind_of?(Integer)); x = (x..x) end
      if (y.kind_of?(Integer)); y = (y..y) end
      y.each { |yi|
        x.each { |xi|
          str = "(#{xi},#{yi})"
          nlist.insert(-1, str)
        }
      }
      return nlist
    end
end
