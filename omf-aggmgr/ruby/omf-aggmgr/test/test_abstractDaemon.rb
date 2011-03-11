#
# Copyright (c) 2011 National ICT Australia (NICTA), Australia
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
# = test_abstractDaemon.rb
#
# == Description
#
# This file performs a test of the AbstractDaemon class.  Currently the
# only functionality tested is whether the daemons can be started and
# stopped faithfully.
#
require 'webrick'
include WEBrick  # Because AbstractDaemon is totally brain dead.

require 'omf-aggmgr/ogs/abstractDaemon'

class MockRequest
  attr_accessor :query

  def initialize(hash)
    @query = hash || {}
  end

  def [](key)
    @query[key]
  end
end

class MockDaemon < AbstractDaemon
  attr_reader :port
  def getCommand()
    'ping localhost > /dev/null'
  end
end

class Daemon1 < MockDaemon
  def self.daemon_name(req)
    "daemon1/#{req['name']}"
  end
end

class Daemon2 < MockDaemon
  def self.daemon_name(req)
    "daemon2/#{req['name']}"
  end
end

def run
  Daemon1.configure('testbed' => { 'default' => {}})
  Daemon2.configure('testbed' => { 'default' => {}})

  klasses = [ Daemon1, Daemon2 ]

  klasses.each do |klass|
    10.times do |i|
      req = MockRequest.new('domain' => "domain-#{klass.name}-#{i}",
                            'name' => "daemon-#{klass.name}-#{i}")
      klass.new(req)
    end
  end
  sleep 2

  all_pids = []

  MObject.debug(:test, "Created #{AbstractDaemon.all_classes_instances.length} daemons:")
  klasses.each do |klass|
    failed = []
    pidlist = klass.all.collect do |inst|
      all_pids << inst.pid
      begin
        Process.getpgid(inst.pid)
      rescue Errno::ESRCH
        failed << inst.pid
      end
      inst.pid.to_s
    end.join(", ")
    MObject.debug(:test, "--> #{klass.name}: #{klass.all.length} daemons; pids:  #{pidlist}")
    if failed.length > 0
      failedlist = failed.collect { |f| f.to_s }.join(", ")
      MObject.debug(:test, "--> #{klass.name}: failed to launch: #{failedlist}")
    end
  end

  AbstractDaemon.all_classes_instances.each do |inst|
    MObject.debug(:test, "Killing daemon '#{inst.name}'")
    inst.stop
  end

  sleep 1

  all_pids.each do |pid|
    begin
      Process.getpgid(pid)
      MObject.error(:test, "Daemon #{pid} failed to die!")
    rescue Errno::ESRCH
    end
  end
end

if __FILE__ == $PROGRAM_NAME then run; end
