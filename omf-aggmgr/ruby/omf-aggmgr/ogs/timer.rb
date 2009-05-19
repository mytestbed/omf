#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 - WINLAB, Rutgers University, USA
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
# = timer.rb
#
# == Description
#
# This file defines the Timer class.
#

require 'omf-common/mobject'

#
# This class defines a Timer which can be associated with a given Grid Service.
# In general when the Timer instance expires, a block of commands is called for
# that given Grid Service.
# This class not only represent a single Timer instance, but it also provides a 
# class-wide array of Timer instances currently used by the various Services.
#
class Timer < MObject

  @@timeouts = Hash.new
  @@timeoutMutex = Mutex.new
  @@timeoutThreads = nil

  #
  # Create and start a new Timer associated with to a key. A block of commands
  # is called after this new Timer expires.
  #
  # - key =  the key to associate with the Timer
  # - timeout = the timeout duration in sec
  # - &block =  the block of commands to execute after 'timeout'  
  #
  def self.register(key, timeout, &block)
    @@timeoutMutex.synchronize {
      debug "Timeout", "Register '#{key||'ANONYMOUS'}'"
      if key != nil && @@timeouts.has_key?(key)
        warn("Overiding exiting timer '#{key}'")
      end
      key ||= "_ANONYMOUS_" + Time.now.to_i.to_s
      @@timeouts[key] = self.new(timeout, key, &block)
      if (@@timeoutThreads != nil)
        @@timeoutThreads.wakeup
      else
        startThread
      end
    }
  end

  #
  # Renew an existing Timer by given time duration
  #
  # - key =  the key associated with the Timer to renew
  # - time = the extra time duration in sec to renew this Timer for
  #
  def self.renew(key, time)
    t = @@timeouts[key] || raise("Unknown timeout '#{key}'")
    t.renew(time)
  end

  #
  # Cancel a previously set Timer 
  #
  # - key = the key associated with the previously set Timer to cancel
  #
  def self.cancel(key)
    @@timeouts.delete(key)
  end

  #
  # Return the remaining time before a given Timer expires 
  #
  # - key = the key associated with the Timer to query
  #
  # [Return] the time duration before this Timer expires
  #
  def self.timeRemaining(key)
    t = @@timeouts[key] || raise("Unknown timeout '#{key}'")
    t.endTime - Time.now
  end

  private

  #
  # Start a new Timer Thread
  #
  def self.startThread()
    debug "Timeout", "Starting timeout thread"
    @@timeoutThreads = Thread.new() {
      @@timeoutMutex.lock
      while (! @@timeouts.empty?)
        debug "TimeoutThread", "Checking tasks #{@@timeouts.values.length}"
        tasks = @@timeouts.values.sort { |a, b| a.endTime <=> b.endTime }
        #debug "TimeoutThread", "Tasks sorted #{tasks}"
        now = Time.now
        nextTask = tasks.detect { |t|
          debug "TimeoutThread", "Checking #{t}"
          if (t.endTime <= now)
            debug "TimeoutThread", "Timing out #{t.key}"
            begin
              t.block.call
            rescue => ex
              error "TimeoutThread", ex
            end
            @@timeouts.delete(t.key)
            false
          else
            # return the first job in the future
            debug "TimeoutThread", "First job in the future #{t}"
            true
          end
        }
        debug "TimeoutThread", "Next task #{nextTask}"
        if (nextTask != nil)
          delta = nextTask.endTime - now
          debug "TimeoutThread", "Sleeping '#{delta}'"
          @@timeoutMutex.unlock
          sleep delta
          @@timeoutMutex.lock
          debug "TimeoutThread", "Done sleeping"
        end
      end
      @@timeoutThreads = nil
      debug "Timeout", "Stopping timeout thread"
      @@timeoutMutex.unlock
    }
  end

  public
  attr_accessor :endTime, :key, :block

  #
  # Create a new Timer instance
  #
  # - after = timeout duration fort this Timer
  # - key = key to associate to this Timer
  # - &block = block of commands to associate with this Timer
  #
  def initialize(after, key, &block)
    @endTime = Time.now + after
    @key = key
    @block = block
  end

  # 
  # Renew an this Timer instance by a given time duration
  #
  # - after = the duration in sec to renew this Timer for
  #
  def renew(after)
    @endTime = Time.now + after
  end

  #
  # Return a String describing this Timer
  #
  # [Return] a String describing this Timer
  #
  def to_s
    "Timeout(key: '#{key}' endTime: #{endTime - Time.now})"
  end
end

#################################
#
# Some Test Code...
#
##################################
if __FILE__ == $0
  now = Time.now
  Timeout.register('a', 4) { puts "DONE a #{Time.now - now}" }
  Timeout.register('b', 2) { puts "DONE b #{Time.now - now}" }
  Timeout.register('c', 5) { puts "DONE b #{Time.now - now}" }
  sleep 3
  Timeout.renew('a', 2)
  Timeout.cancel('c')
  sleep 10
end
