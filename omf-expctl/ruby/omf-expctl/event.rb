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
  @name = nil
  attr_reader :name

  def [](key)
    return @@events[@name][:actionOptions][key]
  end

  def Event.[] (name)
    return @@events[name]
  end

  def Event.empty?(opts)
    ignoreList = opts[:ignore]
    @@events.each { |name,event|
      if !ignoreList.include?(name)
        return false if event[:running]
      end
    }
    return true
  end

  
  #
  # Event constructor
  #
  def initialize(name, interval = 5, &block)
    super("event::#{name}")
    @name = name
    @@events[@name] = {:instance => self, :interval => interval,
                       :running => false, :fired => false,
                       :thread => nil, 
                       :conditionBlock => block, 
                       :actionBlocks => Queue.new, :actionOptions => Hash.new}
  end

  def start
    @@events[@name][:thread] = Thread.new(self) { |event|
      lines = Array.new
      @@events[@name][:running] = true
      #while Experiment.running?
      while true
        begin 
          conditionBlock = @@events[@name][:conditionBlock]
          conditionBlock.call(event)
          if @@events[@name][:fired]
            info "Event triggered. Starting the associated tasks."
            begin
              if !@@events[@name][:actionBlocks].empty?
                while block = @@events[@name][:actionBlocks].pop
                  block.call(event)
                end
              else
                info "No tasks associated to Event '#{name}'" 
              end
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
          Kernel.sleep(@@events[@name][:interval])
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
    @@events[@name][:fired] = true
    if (options && options.kind_of?(Hash)) 
      @@events[@name][:actionOptions] = options 
    end
  end

  def Event.associate_tasks_to_event(name, &block)
    return if !block
    if !@@events[name] 
      MObject.warn("Event","Event '#{name}' does not exist! Cannot associate "+
                   "a block of tasks to it!")
      return
    end
    @@events[name][:actionBlocks] << block
    @@events[name][:instance].start if !@@events[name][:running] 
  end
 
  def Event.purge_all
    @@events.each { |name, attributes|
      attributes[:thread].kill! if attributes[:running] && attributes[:thread]
    }
    @@events.clear
  end

end
