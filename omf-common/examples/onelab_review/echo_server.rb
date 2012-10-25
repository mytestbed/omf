#!/usr/bin/env ruby1.8
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
# This simple application waits for TCP connections and simply sends back 
# any message it receives until the remote side disconnects.
#
#
require 'socket'
require 'optparse'

APPNAME = 'echo_server'
APPVERSION = "1.0"
#
# This class does all the work.
#
class Worker

  #
  # Initialise a new Worker object
  # - args = the command line argument which was given to this wrapper 
  #          application
  #
  def initialize(args)
    
    @address = 'localhost'
    @port = 4040
    @debug = false

    argParser = OptionParser.new
    argParser.banner = "\nWait for TCP connections and echo any received line back to sender.\n" +
                         "Use -h or --help for a list of options\n\n" 
    argParser.on("-a", "--address HOST_ADDRESS", "Name of host to measure against") { |a| @address = a }
    argParser.on_tail("-v", "--version", "Show the version\n") { |v| puts "Version: #{APPVERSION}"; exit }
    argParser.on("-d", "--debug", "Print debugging messages") { @debug = true }
    argParser.parse(args)


    @socket = TCPServer.open(@address, @port)
    puts "Opened socket #{@address}:#{@port}: #{@socket}" if @debug
  end
    
  #  
  # Now measure
  #
  def start()
    # Loop until the user interrupts us
    loop do
      Thread.start(@socket.accept) do |client|
        begin 
          puts "Received connection <#{client.inspect}>" if @debug
          loop do
            puts "Waiting" if @debug
            msg = client.gets
            puts "Sending" if @debug
            client.puts msg
          end
        rescue
        end
        puts "Closing" if @debug
        client.close
      end
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
