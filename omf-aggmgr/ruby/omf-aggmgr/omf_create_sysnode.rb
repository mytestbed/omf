#!/usr/bin/env ruby
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

require "omf-common/communicator/xmpp/omfXMPPServices"

#Jabber::debug = true

PUBSUB_USER = "aggmgr"
PUBSUB_PWD = "123"

@domain = nil
@service = nil

class Node
  @name = nil
  def initialize(name)
    @name = name
  end

  def + (name)
    new_name = @name + "/" + name
    Node.new(new_name)
  end

  def to_s
    @name
  end
end

OMF = Node.new("/OMF")
SYSTEM = OMF + "system"

# ------- SUPPORTING FUNCTIONS -------

def service
  if @service.nil?
    begin
      @service = OmfXMPPServices.new(PUBSUB_USER, PUBSUB_PWD, @domain)
      @service.add_service(@domain)
      puts "Connected to PubSub Server: '#{ARGV[0]}'"
    rescue Exception => ex
      puts "ERROR Creating ServiceHelper - '#{ex}'"
    end
  end
  @service
end

def mknode(node)
  service.create_node(node.to_s, @domain)
end

def rmnode(node)
  if node.kind_of? String
    service.remove_node(node, @domain)
  elsif node.kind_of? Node
    service.remove_node(node.to_s, @domain)
  else
    raise "rmnode:  Not String or Node"
  end
end

def getallnodes
  helper = service.service(@domain)
  browser = Jabber::PubSub::NodeBrowser.new(helper.stream)
  serviceJID = helper.to_s
  browser.nodes(serviceJID)
end

#-------- COMMAND Definition & Lookup ---------

@commands = Hash.new
@help = Hash.new

def command(descr, &block)
  name = descr.split(" ")[0].lstrip.rstrip
  helpstring = descr[name.length..-1]
  @commands[name] = Proc.new &block
  @help[name] = helpstring
end

def nocommand(descr, &block)
  nil
end

def trycommand(command)
  if @commands.has_key? command
    @commands[command]
  else
    puts "Unknown command '#{command}'"
    usage
    service.stop
    exit 0
  end
end

def exec(command, args)
  trycommand(command).call(args)
end

def help(command)
  trycommand(command).call(args)
end

#------ COMMANDS --------

command("mknode <name> -- create a new node with given <name>")\
do |args|
  mknode(args[0])
end

command("rmnode <name> -- delete the named node (only if owner!)")\
do |args|
  rmnode(args[0])
end

# Remove all nodes under the given one.  i.e. rmunder("/OMF/system")
# will delete "/OMF/system/omf.nicta.node1",
# "/OMF/system/omf.nicta.node2", ... But NOT "/OMF/system" iteself.
command("rmunder <prefix> -- delete all nodes whose names start with <prefix> (only if owner!)")\
do |args|
  prefix = args[0]
  nodes = getallnodes.reject { |s| not s.match("^#{prefix}") }
  nodes.each { |n| puts "Deleting node '#{n}':  #{if rmnode(n) then "success" else "failure" end}" }
end

command("mksys -- create the system nodes /OMF and /OMF/system")\
do |args|
  [OMF, SYSTEM].each do |n|
    begin
      mknode(n)
    rescue Exception => e
      puts "Error creating node #{n.to_s}: #{e}"
    end
  end
end

command("mkslice <name> [resource*] -- create a slice node and nodes for the named resources belonging to it")\
do |args|
  slice = args[0]
  resources = args[1..-1]
  mknode(OMF + slice)
  mknode(OMF + slice + "resources")
  resources.each { |r| mknode(OMF + slice + "resources" + r) }
end

command("sliceadd <slice> [<resource>*] -- add a (list of) resource(s) to a <slice>")\
do |args|
  slice = args[0]
  resources = args[1..-1]
  resources.each { |r| mknode(OMF + slice + "resources" + r) }
end

command("resourceadd [<resource>*] -- add a (list of) resource(s) to the system nodes (under /OMF/system)")\
do |args|
  args.each { |r| mknode(SYSTEM + r) }
end

command("listall <name> -- list all pubsub nodes on the given domain")\
do |args|
  getallnodes.sort.each { |n| p n }
end

command("help <command> -- get help on <command>")\
do |args|
  if args.length == 0
    usage
  else
    command = args[0]
    help = @help[command]
    puts "Usage:  "
    puts "     #{$0} <domain> #{command} #{help}"
    puts ""
    exit 0
  end
end

# -------- END COMMANDS ---------

def usage
  puts "Usage:"
  puts "   #{$0} <XMPP-server> <command> [OPTIONS]"
  puts ""
  puts "   <command> is one of:"
  @commands.each_key { |k| puts "        #{k}" }
  puts ""
end

def run
  if ARGV.length < 2
    usage
    exit 0
  end

  @domain = ARGV[0]

  command = ARGV[1]
  args = ARGV[2..-1]

  if @commands.has_key? command
    @commands[command].call(args)
  else
    puts "Unknown command '#{command}'"
    usage
    service.stop
    exit 0
  end
end

run if __FILE__ == $PROGRAM_NAME
