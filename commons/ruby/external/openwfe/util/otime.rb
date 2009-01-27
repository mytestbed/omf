#
#--
# Copyright (c) 2005-2007, John Mettraux, OpenWFE.org
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
# $Id: otime.rb 3509 2006-10-21 12:00:52Z jmettraux $
#

#
# "hecho en Costa Rica"
#
# john.mettraux@openwfe.org
#

require 'date'
#require 'parsedate'


module OpenWFE

    #TIME_FORMAT = "%Y-%m-%d %H:%M:%S"

    #
    # Returns the current time as an ISO date string
    #
    def OpenWFE.now ()
        return to_iso8601_date(Time.new())
    end

    def OpenWFE.to_iso8601_date (date)

        if date.kind_of? Float 
            date = to_datetime(Time.at(date))
        elsif date.kind_of? Time
            date = to_datetime(date)
        elsif not date.kind_of? Date
            date = DateTime.parse(date)
        end

        s = date.to_s
        s[10] = " "

        return s
    end

    #
    # the old method we used to generate our ISO datetime strings
    #
    def OpenWFE.time_to_iso8601_date (time)

        s = time.getutc().strftime(TIME_FORMAT)
        o = time.utc_offset / 3600
        o = o.to_s + "00"
        o = "0" + o if o.length < 4
        o = "+" + o unless o[0..1] == '-'

        s + " " + o.to_s
    end

    #
    # Returns a Ruby time
    #
    def OpenWFE.to_ruby_time (iso_date)

        return DateTime.parse(iso_date)
    end

    #def OpenWFE.parse_date (date)
    #end

    #
    # equivalent to java.lang.System.currentTimeMillis()
    #
    def OpenWFE.current_time_millis ()

        t = Time.new()
        t = t.to_f * 1000
        return t.to_i
    end

    #
    # turns a string like '1m10s' into a float like '70.0'
    #
    # w -> week
    # d -> day
    # h -> hour
    # m -> minute
    # s -> second
    # M -> month
    # y -> year
    # 'nada' -> millisecond
    #
    def OpenWFE.parse_time_string (string)

        string = string.strip

        index = -1
        result = 0.0

        number = ""

        while true
            index = index + 1

            if index >= string.length
                if number.length > 0
                    result = result + (Float(number) / 1000.0)
                end
                break
            end

            c = string[index, 1]

            if is_digit?(c)
                number = number + c
                next
            end

            value = Integer(number)
            number = ""

            multiplier = DURATIONS[c]

            raise "unknown time char '#{c}'" \
                if not multiplier

            result = result + (value * multiplier)
        end

        return result
    end

    #
    # returns true if the character c is a digit
    #
    def OpenWFE.is_digit? (c)
        return false if not c.kind_of?(String)
        return false if c.length > 1
        return (c >= "0" and c <= "9")
    end

    #
    # conversion methods between Date[Time] and Time

    #
    # Ruby Cookbook 1st edition p.111
    # http://www.oreilly.com/catalog/rubyckbk/
    # a must
    #

    #
    # converts a Time instance to a DateTime one
    #
    def OpenWFE.to_datetime (time)

        s = time.sec + Rational(time.usec, 10**6)
        o = Rational(time.utc_offset, 3600 * 24)

        begin

            return DateTime.new(
                time.year, 
                time.month, 
                time.day, 
                time.hour, 
                time.min, 
                s, 
                o)

        rescue Exception => e

            #puts
            #puts OpenWFE::exception_to_s(e)
            #puts
            #puts \
            #    "\n Date.new() problem. Params :"+
            #    "\n....y:#{time.year} M:#{time.month} d:#{time.day} "+
            #    "h:#{time.hour} m:#{time.min} s:#{s} o:#{o}"

            return DateTime.new(
                time.year, 
                time.month, 
                time.day, 
                time.hour, 
                time.min, 
                time.sec, 
                time.utc_offset)
        end
    end

    def OpenWFE.to_gm_time (dtime)
        to_ttime(dtime.new_offset, :gm)
    end

    def OpenWFE.to_local_time (dtime)
        to_ttime(dtime.new_offset(DateTime.now.offset-offset), :local)
    end

    def to_ttime (d, method)
        usec = (d.sec_fraction * 3600 * 24 * (10**6)).to_i
        Time.send(method, d.year, d.month, d.day, d.hour, d.min, d.sec, usec)
    end

    protected

        DURATIONS = {
            "y" => 365 * 24 * 3600,
            "M" => 30 * 24 * 3600,
            "w" => 7 * 24 * 3600,
            "d" => 24 * 3600,
            "h" => 3600,
            "m" => 60,
            "s" => 1
        }

end

