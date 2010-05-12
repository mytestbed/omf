#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
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
# = event.rb
#
# == Description
#
# This file defines the ...
#

#
# This class implements an Event which can be used by users/experimenters 
# to describe a particular event to monitor for and to act upon
#
class Event < MObject

  @@events = Hash.new
  @@eventFired = Hash.new
  @name = nil
  @options = Hash.new
  attr_reader :name

  #
  # Event constructor
  #
  def initialize(name, interval = 5, &block)
    super("event::#{name}")
    @@eventFired[name] = false
    Thread.new(self) { |event|
      lines = Array.new
      while Experiment.running?
        begin 
          block.call(event)
          if @@eventFired[name]
            info "Event triggered. Starting the associated tasks."
            begin
              taskBlock = @@events[name]
              taskBlock.call(event) if taskBlock
              info "No tasks associated to Event '#{name}'" if !taskBlock
            rescue Exception => ex
              lines << "Failed to execute tasks associated with Event"
              lines << "Error (#{ex.class}): '#{ex}'"
              lines << "(More information in the log file)"
	      NodeHandler.instance.display_error_msg(lines)
              bt = ex.backtrace.join("\n\t")
              debug "Exception: #{ex} (#{ex.class})\n\t#{bt}"
            end
            # done
            break
          end
          Kernel.sleep(interval)
        rescue Exception => ex
          lines << "Failed to create the new Event '#{name}'"
          lines << "Error (#{ex.class}): '#{ex}'"
          lines << "(More information in the log file)"
	  NodeHandler.instance.display_error_msg(lines)
          bt = ex.backtrace.join("\n\t")
          debug "Exception: #{ex} (#{ex.class})\n\t#{bt}"
        end
      end
    }
  end

  def fire(options = nil)
    @@eventFired[name] = true
    @options = option if (options && options.kind_of?(Hash)) 
  end

  def Event.associate_tasks_to_event(name, &block)
    return if !block
    if @@events[name] 
      MObject.warn("Event","Event '#{name}' already has some associated tasks")
      MObject.warn("Event","The new defined tasks will overwrite the old ones")
    end
    @@events[name] = block
  end

  def [](key)
    return @options[key]
  end

end
