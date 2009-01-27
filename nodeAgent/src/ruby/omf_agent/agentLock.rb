#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 WINLAB, Rutgers University, USA
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
# = agentLock.rb
#
# == Description
#
# This file defines the SynchronizedNames class 
#
require 'thread'
require 'monitor'
require 'util/mobject'
require 'util/syncVariables'

#
# This class defines a SynchronizedNames, which is a sub-class of SynchronizedArray
# This class will holds the 'names' used by this NA, and allows Thread-safe access to them
#
class SynchronizedNames < SynchronizedArray

   #
   # Reset the array of names, and assign 'value' to its first element
   #
   # - value =  the value to give to the first name, after reset
   #
   # [Return] the last element of the array of names
   #
   def reset(value)
      @lock.synchronize {
         @var.clear
         @var[0] = value
         return @var.last
      }
   end

   #
   # Test if a specific 'target' match any element in this array of names
   #
   # - regTarget = the specific target to match
   #
   # [Return] true/1 if a name match the target, false/0 otherwise
   #
   def match(regTarget)
      @var.each { |name|
         if (regTarget.match(name) != nil)
           #debug "Match #{name} => #{target}"
           return 1
         end
      }
      return 0
   end
end
