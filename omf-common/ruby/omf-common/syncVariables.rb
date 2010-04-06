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
