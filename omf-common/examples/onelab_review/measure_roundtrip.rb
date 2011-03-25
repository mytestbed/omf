#!/usr/bin/ruby1.8
#
# Copyright (c) 2010 National ICT Australia (NICTA), Australia
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
# = measure_roundtrip.rb
#
# == Description
#
# This is a simple application opens a TCP connection to a remote echo server,
# send a small packet, and then measures how long it takes to receive the 
# reply.
#
#

require "oml4r"

APPNAME = 'measure_roundtrip'
APPPATH = "/sbin/#{APPNAME}"
APPVERSION = "1.0"

#
# This class defines the Measurement Point for our application and the
# corresponding metrics we would like to capture
#
class MyMeasurementPoint < OML4R::MPBase
    name :roundtrip
    param :addr
    param :roundtrip, :type => :double
end

#
# This class does all the work.
#
class Worker

  #
  # Initialise a new Wrapper object
  # - args = the command line argument which was given to this wrapper 
  #          application
  #
  def initialize(args)
    
    @address = nil
    @port = 4040
    @interval = 1
    @debug = false
    @rtt_proc = '/proc/net/madwifi/ath0/onelab_proc_file'

    # Now call the Init of OML4R with the command line arguments (args)
    # and a block defining the arguments specific to this wrapper
    OML4R::init(args) { |argParser|
      argParser.banner = "\nPeriodically measure the roundtrip to a specific host.\n" +
                         "Use -h or --help for a list of options\n\n" 
      argParser.on("-a", "--address HOST_ADDRESS", "Name of host to measure against") { |a| @address = a }
      argParser.on("-s", "--sampling DURATION", "Interval in second between sample collection for OML [#{@interval}]") do |t| 
        @interval = t 
      end
      argParser.on("-b", "--beacon-file BEACON_FILE", "File to write RTT values to [#{@rtt_proc}]") do |n| 
        @rtt_proc = n
      end
      argParser.on("-d", "--debug", "Print debugging messages") { @debug = true }
      argParser.on_tail("-v", "--version", "Show the version\n") { |v| puts "Version: #{APPVERSION}"; exit }
    }

    unless @address
      raise "You did not specify an address (-a option)"
    end

    @socket = TCPSocket.open(@address, @port)
    puts "Opened socket to #{@address}:#{@port}: #{@socket}" if @debug
  end
    
  #  
  # Now measure
  #
  def start()
    # Start thread listening for echo replies
    Thread.start() do ||
      while @socket do
        begin 
          puts "Waiting" if @debug
          echo = @socket.gets
          ts = echo.to_f
          if ts > 0.0
            rtt = Time.now.to_f - ts
            puts "RTT: #{rtt}" if @debug
            # Inject the measurements into OML 
            MyMeasurementPoint.inject(@address, rtt)
            File.open(@rtt_proc) do |f|
              f.puts((rtt * 1000).to_i)
            end if @rtt_proc
          else
            puts "WARN: Can't parse received message <#{echo}>"
          end
        rescue
        end
      end
    end

    # Send messages until the user interrupts us
    while true
      pkt = Time.now.to_f.to_s
      puts "Sending <#{pkt}>"  if @debug
      @socket.puts pkt
      # Wait for a given duration and loop again
      sleep @interval.to_i
    end
  end
end

#
# Entry point to this Ruby application
#
begin
  app = Worker.new(ARGV)
  app.start()
rescue SystemExit
rescue SignalException
  puts "#{APPNAME} stopped."
rescue Exception => ex
  puts "Error - When executing '#{APPNAME}':"
  puts "Error - Type: #{ex.class}"
  puts "Error - Message: #{ex}\n\n"
  # Uncomment the next line to get more info on errors
  puts "Trace - #{ex.backtrace.join("\n\t")}"
end
