
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
