#
# Implements multi-dimensional array.
#
# Thanks to Leo
#
class ArrayMD < Array

  def [](n)
    self[n]=ArrayMD.new if super(n)==nil
    super(n)
  end

  def each(&block)
    self.to_a.each { |o|
      if o.kind_of?(Array)
        o.each(&block)
      elsif (o != nil)
        block.call(o)
      end
    }
  end
end

if $0 == __FILE__

amd=ArrayMD.new

amd[2][3][2]='Max'
amd[2][2] = 'Foo'

p amd #=> [nil, nil, [nil, nil, nil, [nil, nil, "Max"]]]

amd.each {|o| p o }

end
