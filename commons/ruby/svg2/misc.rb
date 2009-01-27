
#==============================================================================#
# svg/misc.rb
# $Id: misc.rb,v 1.6 2003/02/06 14:59:43 yuya Exp $
#==============================================================================#

#==============================================================================#
# SVG Module
module SVG2

  #============================================================================#
  # Point Class
  class Point

    def initialize(x, y)
      @x = x
      @y = y
    end

    attr_accessor :x, :y

    def self.[](*points)
      if points.size % 2 == 0
        return (0...(points.size / 2)).collect { |i|
          self.new(points[i * 2], points[i * 2 + 1])
        }
      else
        raise ArgumentError, 'odd number args for Point'
      end
    end

    def to_s
      return "#{@x} #{@y}"
    end

  end # Point

  #============================================================================#
  # GroupMixin Module
  module GroupMixin

    def method_missing(name, *args, &block)
      if (args.size > 1)
        raise "All arguments should be in a single hash"
      end
      className = "SVG2::#{name.to_s.capitalize}"
      clasz = eval(className)
      param = args.size == 1 ? args[0] : {}
      inst = clasz.new(param, &block)
      self << inst
    end
  end

  #============================================================================#
  # ArrayMixin Module
  module ArrayMixin

    include Enumerable

    def array
      raise NotImplementedError
    end
    private :array

    def [](index)
      array[index]
    end

    def []=(index, value)
      array[index] = value
    end

    def <<(other)
      array << other
    end

    def clear
      array.clear
    end

    def first
      array.first
    end

    def last
      array.last
    end

    def each(&block)
      array.each(&block)
    end

  end # ArrayMixin


end # SVG

#==============================================================================#
#==============================================================================#
