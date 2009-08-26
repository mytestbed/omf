require 'thread'
require 'monitor'
require 'omf-common/mobject'

class TypeMismatchException < Exception
end

#
class SynchronizedVariable
  
   def initialize(initValue = nil, type = nil)
     @lock = Monitor.new
     @var = initValue
     @type = type
   end

   def get
     @lock.synchronize {
       return @var.dup
     }
   end

   def set(value)
     if (@type && !value.kind_of?(@type))
       raise TypeMismatchException.new("Expected type '#{@type}' but got #{value.class}'")
     end
     @lock.synchronize {
       @var = value
       return @var
     }
   end
end


#
class SynchronizedInteger < SynchronizedVariable

   def initialize(initValue = 0)
     super(initValue, Integer)
   end

#   def set(value)
#     #if (! value.kind_of Integer)
#       # not sure what an appropriate exception is here
#     #  throw IllegalNumberException("Not an Integer")
#     #end
#     super(value)
#   end

   def incr(step = 1)
     @lock.synchronize {
       @var += step
       return @var
     }
   end

#   def get
#     # no need to 
#     @lock.synchronize {
#       return @var
#     }
#   end

end


#
class SynchronizedArray < SynchronizedVariable

  def initialize(initSize = 1)
    super(Array.new(initSize), Array)
  end

  def [](i)
    @lock.synchronize {
      return @var[i]
    }
  end

  def []=(i, value)
    @lock.synchronize {
      @var[i] = value
    }
    return value
  end

  def append(value)
    @lock.synchronize {
      @var.insert(-1, value)
    }
    value      
  end

  def size
    @lock.synchronize {
      return @var.length
    }
  end

  def clear
    @lock.synchronize {
      @var.clear
    }
  end

  def delete(i)
    @lock.synchronize {
      @var.delete(i)
    }
  end

end

class SynchronizedHash < SynchronizedVariable
   def initialize
     super(Hash.new, Hash)
   end

   def [](key)
     @lock.synchronize {
       return @var[key]
     }
   end

   def []=(key, value)
     @lock.synchronize {
       @var[key] = value
       return value
     }
   end


   def size
     @lock.synchronize {
       return @var.length
     }
   end

   def clear
     @lock.synchronize {
       @var.clear
     }
   end

   def delete(key)
     @lock.synchronize {
       @var.delete(key)
     }
     key
   end

end



#Usage:

#  syncString = SynchronizedVariable.new("")
#  syncString.set("Something")
#
#  syncInt = SynchronizedInteger
#  syncInt.set(3)
#  syncInt.incr
#  syncInt.incr(2)
#  syncInt.get
#
#  syncArray = SynchronizedArray.new(3)
#  syncArray[0] = 23
###  syncArray[0]
