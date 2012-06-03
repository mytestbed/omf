#!/usr/bin/ruby

require 'time'

$debug = false

class LogParse
  i = 0
  EVENT = {
    'node.reset' => i += 1,
    'node.created' => i += 1,
    'node.enrolled' => i += 1,
    'load.start' => i += 1,
    'load.10' => i += 1,
    'load.20' => i += 1,
    'load.30' => i += 1,
    'load.40' => i += 1,
    'load.50' => i += 1,
    'load.60' => i += 1,
    'load.70' => i += 1,
    'load.80' => i += 1,
    'load.90' => i += 1,
    'load.100' => i += 1,
    'load.done' => i += 1,
  }

  def event(name, time, node)
    node = node.split('.')[0]
    row = [time, node, name, EVENT[name] || name]
    puts(row.inspect) if $debug
    @table.add_row row
  end

  # APP_EVENT STARTED from: 'builtin:load_image' (node18-5.grid.orbit-lab.org) - msg: ''
  # APP_EVENT STDOUT from: 'builtin:load_image' (node18-5.grid.orbit-lab.org) - msg: 'Progress: 20% 000136 000224'
  # APP_EVENT DONE.OK from: 'builtin:load_image' (node18-5.grid.orbit-lab.org) - msg: 'status: 9'
  def parse_builtin(time, level, l)
    m = l.match(/.*APP_EVENT ([^ ]*).*'builtin:load_image' \(([^\)]*)\) - msg: '(.*)/)
    return unless m

    action, node, message = m.to_a[1 .. -1]
    message = message[0 .. -2] # chop of ending '
    case action
    when 'STARTED'
      puts "#{time}: #{node} Loading STARTED" if $debug
      event('load.start', time, node)
    when /DONE/
      puts "#{time}: #{node} Loading #{action}" if $debug
      event('load.done', time, node)
    when 'STDOUT'
      return if message.empty?
      if m = message.match(/Progress: ([0-9]*)%/)
        puts "#{time}: #{node} Progress <#{m[1]}> (#{message})"  if $debug
        event("load.#{m[1]}", time, node)
      elsif m = message.match(/Wrote [0-9]* bytes \([0-9]* actual\)/)
        puts "#{time}: #{node} Progress <100> (#{message})"  if $debug
        event("load.100", time, node)
      elsif message.match(/Left the team after [0-9]* seconds on the field/)
      else 
        puts "#{time}: #{node}: ????? (#{message})" if $debug
      end
    else
      puts "#{time}: #{node} UNKNOWN #{action}" if $debug
    end
    #puts "#{node}:#{action}:#{message}"
  end

  # nodeHandler::node::node19-6.grid.orbit-lab.org: Node node19-6.grid.orbit-lab.org is Up and Enrolled
  def parse_nodehandler(time, level, l)
    m = l.match(/ nodeHandler::node::([^:]*): (.*)/)
    return unless m

    node, msg = m.to_a[1 .. -1]
  #  puts "#{time}: #{node} - #{msg}"

    if msg.match /Created node/
      event('node.created', time, node)
    elsif msg.match /Enrolled in ALL its groups/
      event('node.enrolled', time, node)
      puts "Node #{node} enrolled" if $debug
    elsif msg.match /Resetting node/
      event('node.reset', time, node)
    else 
      #puts "#{time}: #{node}: ????? (#{msg})"
    end
  end

  def self.create_table(name)
    require 'omf-oml/table'

    # Create a table containing 'amplitude' measurements taken at a certain time for two different 
    # devices.
    #

    schema = [[:t, :float], [:node, :string], [:event, :string], [:progress, :int]]
    table = OMF::OML::OmlTable.new name, schema

    require 'omf_web'
    OMF::Web.register_datasource table
  end
    

  def initialize(fname, table)
    @table = table
    startTime = nil
    
    fname = File.expand_path(fname)
    unless File.readable?(fname)
      $stderr.puts "Can't find or open file '#{fname}'"
    end

    File.open(fname).each_line do |l|
      m = l.match(/([^A-Z]*)([^ ]*)(.*)/)
      next unless m
      ts, level, rest = m.to_a[1 .. -1]
      ts = Time.parse(ts)
      startTime ||= ts
      time = ts - startTime

      parse_builtin(time, level, rest)
      parse_nodehandler(time, level, rest)
    end
  end
end

table = LogParse.create_table('loading')
[
  'pxe_slice-2012-06-02t02.25.00-04.00.log'
].each do |f|
  LogParse.new "data_sources/#{f}", table
end
