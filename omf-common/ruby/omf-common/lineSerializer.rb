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
# This class implements a line serialzer for a
# simple token array. The only wrinkle here is that
# it treats strings between '"' as single token
#
class LineSerializer

  # Convert string to an array of tokens
  #
  def LineSerializer.to_a(str)

    a = Array.new
    inString = false
    isEscaped = false
    str.scan(/("?)([^"\\]*)(\\?)/) {|pre, middle, post|
      #p "pre: '#{pre}' middle: '#{middle}' post: #{post}"
      if pre == ''
        a += middle.split
      elsif pre == '"'
        if (inString && !isEscaped)
          a += middle.split
          inString = false
        else
          if isEscaped
            a[-1] += "\"#{middle}"
          else
            a << middle
          end
          inString = true
        end
        isEscaped = post == '\\'
      end
    }
    return a
  end

  def LineSerializer.to_s(array)
    if (array == nil)
      return ""
    end
    s = String.new
    array.each {|e|
      es = e.to_s
      if (es.split.length > 1)

        s << "\"#{es.gsub('"', '\"')}\" "
      else
        s << "#{es} "
      end
    }
    return s.rstrip
  end
end

if $0 == __FILE__

a = LineSerializer.to_a('s1 s2 "long string" s3')
puts "1>> #{a.join('|')}\n"

a = LineSerializer.to_a('s1   s2 "long \"\" escaped \" string" s3')
puts "2>> #{a.join('|')}"

puts "#{LineSerializer.to_s(a)}"


end
