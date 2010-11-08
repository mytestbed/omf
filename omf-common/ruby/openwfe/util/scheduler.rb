#
#--
# Copyright (c) 2006-2007, John Mettraux, OpenWFE.org
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
# 
# . Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.  
# 
# . Redistributions in binary form must reproduce the above copyright notice, 
#   this list of conditions and the following disclaimer in the documentation 
#   and/or other materials provided with the distribution.
# 
# . Neither the name of the "OpenWFE" nor the names of its contributors may be
#   used to endorse or promote products derived from this software without
#   specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.
#++
#
# $Id: definitions.rb 2725 2006-06-02 13:26:32Z jmettraux $
#

#
# "made in Japan"
#
# John Mettraux at openwfe.org
#

require 'monitor'
require 'openwfe/omf-common/otime'

module OpenWFE

    #
    # The Scheduler is used by OpenWFEru for registering 'at' and 'cron' jobs.
    # 'at' jobs to execute once at a given point in time. 'cron' jobs
    # execute a specified intervals.
    # The two main methods are thus schedule_at() and schedule().
    #
    # schedule_at() and schedule() await either a Schedulable instance and 
    # params (usually an array or nil), either a block, which is more in the 
    # Ruby way.
    #
    # Two examples :
    #     
    #    scheduler.schedule_in("3d") do
    #        regenerate_monthly_report()
    #    end
    #        # 
    #        # will call the regenerate_monthly_report method 
    #        # in 3 days from now
    #
    # and
    #
    #    class Regenerator < Schedulable
    #        def trigger (frequency)
    #            self.send(frequency)
    #        end
    #        def monthly
    #            # ...
    #        end
    #        def yearly
    #            # ...
    #        end
    #    end
    #
    #    regenerator = Regenerator.new
    #
    #    scheduler.schedule_in("4d", regenerator, :monthly)
    #        # 
    #        # will regenerate the monthly report in four days
    #
    # There is also schedule_every() :
    #
    #     scheduler.schedule_every("1h20m") do
    #         regenerate_latest_report()
    #     end
    #
    # The scheduler has a "exit_when_no_more_jobs" attribute. When set to
    # 'true', the scheduler will exit as soon as there are no more jobs to
    # run.
    # Use with care though, if you create a scheduler, set this attribute
    # to true and start the scheduler, the scheduler will immediately exit.
    # This attribute is best used indirectly : the method 
    # join_until_no_more_jobs() wraps it.
    #
    class Scheduler
        include MonitorMixin

        attr_accessor \
            :precision,
            :exit_when_no_more_jobs

        def initialize

            super()

            @pending_jobs = []
            @cron_entries = {}

            @scheduler_thread = nil

            @precision = 0.250
                #
                # every 250ms, the scheduler wakes up

            @exit_when_no_more_jobs = false
            @dont_reschedule_every = false

            @last_cron_minute = -1

            @stopped = false
        end

        #
        # Starts this scheduler (or restart it if it was previously stopped)
        #
        def sstart

            @scheduler_thread = Thread.new do
                while true
                    break if @stopped
                    step
                    sleep(@precision)
                end
            end
        end

        #
        # The scheduler is stoppable via sstop()
        #
        def sstop

            @stopped = true
        end

        alias :start :sstart
        alias :stop :sstop

        #
        # Joins on the scheduler thread
        #
        def join

            @scheduler_thread.join
        end

        #
        # Like join() but takes care of setting the 'exit_when_no_more_jobs'
        # attribute of this scheduler to true before joining.
        # Thus the scheduler will exit (and the join terminates) as soon as
        # there aren't no more 'at' (or 'every') jobs in the scheduler.
        #
        # Currently used only in unit tests.
        #
        def join_until_no_more_jobs

            @exit_when_no_more_jobs = true
            join
        end

        #
        # Schedules a job by specifying at which time it should trigger.
        # Returns the a job_id that can be used to unschedule the job.
        #
        def schedule_at (at, schedulable=nil, params=nil, &block)

            sschedule_at(false, at, nil, schedulable, params, &block)
        end


        #
        # Schedules a job by stating in how much time it should trigger.
        # Returns the a job_id that can be used to unschedule the job.
        #
        def schedule_in (duration, schedulable=nil, params=nil, &block)

            duration = duration_to_f(duration)

            return schedule_at(
                Time.new.to_f + duration, schedulable, params, &block)
        end

        #
        # Schedules a job in a loop. After an execution, it will not execute
        # before the time specified in 'freq'.
        #
        # Note that if your job takes 2s to execute and the freq is set to
        # 10s, it will in fact execute every 12s.
        # You can however wrap the code within its own thread :
        #
        #     scheduler.schedule_every("12s") do
        #         Thread.new do
        #             do_the_job()
        #         end
        #     end
        #
        def schedule_every (freq, schedulable=nil, params=nil, &block)

            sschedule_every(freq, nil, schedulable, params, &block)
        end

        #
        # Unschedules an 'at' or a 'cron' job identified by the id
        # it was given at schedule time.
        #
        def unschedule (job_id)
            synchronize do

                for i in 0...@pending_jobs.length
                    if @pending_jobs[i].eid == job_id
                        @pending_jobs.delete_at(i)
                        return true
                    end
                end

                return true if unschedule_cron_job(job_id)

                return false
            end
        end

        #
        # Unschedules a cron job
        #
        def unschedule_cron_job (job_id)
            synchronize do
                if @cron_entries.has_key?(job_id)
                    @cron_entries.delete(job_id)
                    return true
                end
                return false
            end
        end

        #
        # Schedules a cron job, the 'cron_line' is a string
        # following the Unix cron standard (see "man 5 crontab" in your command 
        # line).
        #
        # For example :
        #
        #    scheduler.schedule("5 0 * * *", nil, s, p)
        #        # will trigger the schedulable s with params p every day
        #        # five minutes after midnight
        #
        #    scheduler.schedule("15 14 1 * *", nil, s, p)
        #        # will trigger s at 14:15 on the first of every month
        #
        #    scheduler.schedule("0 22 * * 1-5") do
        #        puts "it's break time..."
        #    end
        #        # outputs a message every weekday at 10pm
        #
        # Returns the job id attributed to this 'cron job', this id can
        # be used to unschedule the job.
        #
        def schedule (
            cron_line, cron_id=nil, schedulable=nil, params=nil, &block)

            synchronize do
            
                #
                # is a job with the same id already scheduled ?

                if cron_id and unschedule(cron_id)
                    ldebug do 
                        "schedule() unscheduled previous job "+
                        "under same name '#{cron_id}'"
                    end
                end

                #
                # schedule

                b = to_block(schedulable, params, &block)
                entry = CronEntry.new(cron_id, cron_line, &b)
                @cron_entries[entry.eid] = entry

                return entry.eid
            end
        end

        #
        # Returns the job corresponding to job_id, an instance of AtEntry
        # or CronEntry will be returned.
        #
        def get_job (job_id)

            entry = @cron_entries[job_id]
            return entry if entry

            @pending_jobs.each do |entry|
                return entry if entry.eid == job_id
            end

            return nil
        end

        #
        # Finds a job (via get_job()) and then returns the wrapped 
        # schedulable if any.
        #
        def get_schedulable (job_id)

            return nil unless job_id

            j = get_job(job_id)

            return j.schedulable if j.respond_to? :schedulable
            return nil
        end

        #
        # Returns the number of currently pending jobs in this scheduler
        # ('at' jobs and 'every' jobs).
        #
        def pending_job_count
            @pending_jobs.size
        end

        #
        # Returns the number of cron jobs currently active in this scheduler.
        #
        def cron_job_count
            @cron_entries.size
        end

        #
        # Returns the current count of 'every' jobs scheduled.
        #
        def every_job_count
            @pending_jobs.select { |j| j.is_a?(EveryEntry) }.size
        end

        #
        # Returns the current count of 'at' jobs scheduled (not 'every').
        #
        def at_job_count
            @pending_jobs.select { |j| j.instance_of?(AtEntry) }.size
        end

        #
        # Returns true if the given string seems to be a cron string.
        #
        def Scheduler.is_cron_string (s)
            return s.match(".+ .+ .+ .+ .+")
        end

        protected

            def sschedule_at (
                is_every, at, at_id, schedulable=nil, params=nil, &block)

                synchronize do

                    #puts "0 at is '#{at.to_s}' (#{at.class})"

                    at = OpenWFE::to_ruby_time(at) \
                        if at.kind_of? String

                    at = OpenWFE::to_gm_time(at) \
                        if at.kind_of? DateTime

                    at = at.to_f \
                        if at.kind_of? Time

                    #puts "1 at is '#{at.to_s}' (#{at.class})"}"

                    jobClass = AtEntry
                    jobClass = EveryEntry if is_every

                    b = to_block(schedulable, params, &block)
                    job = jobClass.new(at, at_id, &b)

                    if at < (Time.new.to_f + @precision)
                        job.trigger()
                        return nil
                    end

                    return push(job) \
                        if @pending_jobs.length < 1

                    # shortcut : check if the new job is posterior to
                    # the last job pending

                    return push(job) \
                        if at >= @pending_jobs.last.at

                    for i in 0...@pending_jobs.length
                        if at <= @pending_jobs[i].at
                            return push(job, i)
                        end
                    end

                    return push(job)
                end
            end

            def sschedule_every (freq, at_id, schedulable, params, &block)

                f = duration_to_f(freq)

                job_id = sschedule_at(
                    true, Time.new.to_f + f, at_id) do |eid, at|

                    if schedulable
                        schedulable.trigger(params)
                    else
                        block.call eid, at
                    end
                    
                    sschedule_every(f, eid, schedulable, params, &block) \
                        unless @dont_reschedule_every
                end

                job_id
            end

            #
            # Ensures that a duration is a expressed as a Float instance.
            #
            #     duration_to_f("10s")
            #
            # will yields 10.0
            #
            def duration_to_f (s)
                return s if s.kind_of? Float
                return OpenWFE::parse_time_string(s) if s.kind_of? String
                return Float(s.to_s)
            end

            def to_block (schedulable, params, &block)
                if schedulable
                    l = lambda do
                        schedulable.trigger(params)
                    end
                    class << l
                        attr_accessor :schedulable
                    end
                    l.schedulable = schedulable
                    l
                else
                    block
                end
            end

            #
            # Pushes an 'at' job into the pending job list
            #
            def push (job, index=-1)

                if index == -1
                    #
                    # push job at the end
                    #
                    @pending_jobs << job
                else
                    #
                    # insert job at given index
                    #
                    @pending_jobs[index, 0] = job
                end

                #puts "push() at '#{Time.at(job.at)}'"

                return job.eid
            end

            #
            # This is the method called each time the scheduler wakes up
            # (by default 4 times per second). It's meant to quickly
            # determine if there are jobs to trigger else to get back to sleep.
            # 'cron' jobs get executed if necessary then 'at' jobs.
            #
            def step
                synchronize do

                    now = Time.new
                    minute = now.min

                    if @exit_when_no_more_jobs

                       if @pending_jobs.size < 1

                            @stopped = true
                            return
                        end

                        @dont_reschedule_every = true if at_job_count < 1
                    end

                    #
                    # cron entries

                    if now.sec == 0 and 
                        (minute > @last_cron_minute or 
                         @last_cron_minute == 59)
                        #
                        # only consider cron entries at the second 0 of a 
                        # minute

                        @last_cron_minute = minute

                        @cron_entries.each do |cron_id, cron_entry|
                            #puts "step() cron_id : #{cron_id}"
                            trigger(cron_entry) if cron_entry.matches? now
                        end
                    end

                    #
                    # pending jobs

                    now = now.to_f
                        #
                        # that's what at jobs do understand

                    while true

                        #puts "step() job.count is #{@pending_jobs.length}"

                        break if @pending_jobs.length < 1

                        job = @pending_jobs[0]

                        #puts "step() job.at is #{job.at}"
                        #puts "step() now is    #{now}"

                        break if job.at > now

                        #if job.at <= now
                            #
                            # obviously

                        trigger(job)

                        @pending_jobs.delete_at(0)
                    end
                end
            end

            def trigger (entry)
                Thread.new do
                    begin
                        entry.trigger
                    rescue Exception => e
                        message =
                            "trigger() caught exception\n" + 
                            OpenWFE::exception_to_s(e)
                        if self.respond_to? :lwarn
                            lwarn { message }
                        else
                            puts message
                        end
                    end
                end
            end
    end

    #
    # This module adds a trigger method to any class that includes it.
    # The default implementation feature here triggers an exception.
    #
    module Schedulable

        def trigger (params)
            raise "trigger() implementation is missing"
        end

        def reschedule (scheduler)
            raise "reschedule() implentation is missing"
        end
    end

    protected

        JOB_ID_LOCK = Monitor.new

        class Entry

            @@last_given_id = 0
                #
                # as a scheduler is fully transient, no need to
                # have persistent ids, a simple counter is sufficient

            attr_accessor \
                :eid, :block

            def initialize (entry_id=nil, &block)
                @block = block
                if entry_id
                    @eid = entry_id
                else
                    JOB_ID_LOCK.synchronize do
                        @eid = @@last_given_id
                        @@last_given_id = @eid + 1
                    end
                end
            end

            #def trigger
            #    @block.call @eid
            #end
        end

        class AtEntry < Entry

            attr_accessor \
                :at

            def initialize (at, at_id, &block)
                super(at_id, &block)
                @at = at
            end

            def trigger
                @block.call @eid, @at
            end
        end

        class EveryEntry < AtEntry
        end

        class CronEntry < Entry

            attr_accessor \
                :cron_line

            def initialize (cron_id, line, &block)

                super(cron_id, &block)

                if line.kind_of? String
                    @cron_line = CronLine.new(line)
                elsif line.kind_of? CronLine
                    @cron_line = line
                else
                    raise \
                        "Cannot initialize a CronEntry " +
                        "with a param of class #{line.class}"
                end
            end

            def matches? (time)
                @cron_line.matches? time
            end

            def trigger
                @block.call @eid, @cron_line
            end
        end

        #
        # A 'cron line' is a line in the sense of a crontab 
        # (man 5 crontab) file line.
        #
        class CronLine

            attr_reader \
                :minutes,
                :hours,
                :days,
                :months,
                :weekdays

            def initialize (line)

                super()

                items = line.split

                if items.length != 5
                    raise \
                        "cron '#{line}' string should hold 5 items, " +
                        "not #{items.length}" \
                end

                @minutes = parse_item(items[0], 0, 59)
                @hours = parse_item(items[1], 0, 24)
                @days = parse_item(items[2], 1, 31)
                @months = parse_item(items[3], 1, 12)
                @weekdays = parse_weekdays(items[4])

                adjust_arrays()
            end

            def matches? (time)

                if time.kind_of?(Float) or time.kind_of?(Integer)
                    time = Time.at(time)
                end

                return false if no_match?(time.min, @minutes)
                return false if no_match?(time.hour, @hours)
                return false if no_match?(time.day, @days)
                return false if no_match?(time.month, @months)
                return false if no_match?(time.wday, @weekdays)

                return true
            end

            #
            # Returns an array of 5 arrays (minutes, hours, days, months, 
            # weekdays).
            # This method is used by the cronline unit tests.
            #
            def to_array
                [ @minutes, @hours, @days, @months, @weekdays ]
            end

            private

                #
                # adjust values to Ruby
                #
                def adjust_arrays()
                    if @hours
                        @hours.each do |h|
                            h = 0 if h == 23
                        end
                    end
                    if @weekdays
                        @weekdays.each do |wd|
                            wd = wd - 1
                        end
                    end
                end

                WDS = [ "mon", "tue", "wed", "thu", "fri", "sat", "sun" ]
                    #
                    # used by parse_weekday()

                def parse_weekdays (item)

                    item = item.downcase

                    WDS.each_with_index do |day, index|
                        item = item.gsub(day, "#{index+1}")
                    end

                    return parse_item(item, 1, 7)
                end

                def parse_item (item, min, max)

                    return nil \
                        if item == "*"
                    return parse_list(item, min, max) \
                        if item.index(",")
                    return parse_range(item, min, max) \
                        if item.index("*") or item.index("-")

                    i = Integer(item)

                    i = min if i < min
                    i = max if i > max

                    return [ i ]
                end

                def parse_list (item, min, max)
                    items = item.split(",")
                    result = []
                    items.each do |i|
                        i = Integer(i)
                        i = min if i < min 
                        i = max if i > max
                        result << i
                    end
                    return result
                end

                def parse_range (item, min, max)
                    i = item.index("-")
                    j = item.index("/")

                    inc = 1

                    inc = Integer(item[j+1..-1]) if j

                    istart = -1
                    iend = -1

                    if i

                        istart = Integer(item[0..i-1])

                        if j
                            iend = Integer(item[i+1..j])
                        else
                            iend = Integer(item[i+1..-1])
                        end

                    else # case */x
                        istart = min
                        iend = max
                    end

                    istart = min if istart < min
                    iend = max if iend > max

                    result = []

                    value = istart
                    while true
                        result << value
                        value = value + inc
                        break if value > iend
                    end

                    return result
                end

                def no_match? (value, cron_values)

                    return false if not cron_values

                    cron_values.each do |v|
                        return false if value == v
                    end

                    return true
                end
        end

end

