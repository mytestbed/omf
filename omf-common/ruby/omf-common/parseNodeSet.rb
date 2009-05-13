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
