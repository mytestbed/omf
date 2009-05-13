require 'thread'
require 'monitor'
require 'omf-common/mobject'

#
class SynchronizedVariable

   def initialize(initValue = nil)
       @lock = Monitor.new
       @var = initValue
   end

   def get
      @lock.synchronize {
         return @var
      }
   end

   def set(value)
      @lock.synchronize {
         @var = value
   return @var
      }
   end
end

#
class SynchronizedInteger < SynchronizedVariable

   def initialize(initValue = 0)
     super(initValue)
   end

   def set(value)
     #if (! value.kind_of Integer)
       # not sure what an appropriate exception is here
     #  throw IllegalNumberException("Not an Integer")
     #end
     super(value)
   end

   def incr(step = 1)
      @lock.synchronize {
         @var += step
   return @var
      }
   end

   def get
      @lock.synchronize {
   return @var
      }
   end

end

#
class SynchronizedArray < SynchronizedVariable

   def initialize(initSize = 1)
     super(Array.new(initSize))
   end

   def [](i)
      @lock.synchronize {
         return @var[i]
      }
   end

   def []=(i, value)
      @lock.synchronize {
         @var[i] = value
   return value
      }
   end

   def append(value)
      @lock.synchronize {
         @var.insert(-1, value)
   return @var.last
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

   def delete(i)
      @lock.synchronize {
   @var.delete(i)
      }
   end

end

class SynchronizedHash < SynchronizedVariable
   def initialize
     super(Hash.new)
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

   def append(value)
      @lock.synchronize {
         @var.insert(-1, value)
   return @var.last
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
