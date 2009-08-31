#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
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
# = nodeSet.rb
#
# == Description
#
# This file also defines the NodeSetPath class 
#
#
require 'set'
require 'omf-common/mobject'
require 'omf-expctl/prototype'
require 'omf-expctl/node/node'
require 'omf-expctl/experiment'
require 'observer'

#
# This class defines a 'PATH' to access/set attributes of a given NodeSet
#
class NodeSetPath < MObject
  attr_reader :nodeSet, :path

  # List of valid 'PATHS' for a NodeSet
  VALID_PATHS_WITH_VALUES = {
    "mode=" => %r{net/[ew][01]},
    "type=" => %r{net/[ew][01]},
    "rts=" => %r{net/[ew][01]},
    "rate=" => %r{net/[ew][01]},
    "essid=" => %r{net/[ew][01]},
    "ip=" => %r{net/[ew][01]},
    "channel=" => %r{net/[ew][01]},
    "tx_power=" => %r{net/[ew][01]},
    "netmask=" => %r{net/[ew][01]},
    "mac=" => %r{net/[ew][01]},
    "mtu=" => %r{net/[ew][01]},
    "arp=" => %r{net/[ew][01]},
    "enforce_link=" => %r{net/[ew][01]},
    "route" => %r{net/[ew][01]},
    "filter" => %r{net/[ew][01]},
    "net" => //
  }
  VALID_PATHS_WITHOUT_VALUES = {
    "down" => %r{net/[ew][01]},
    "up" => %r{net/[ew][01]},
  }
  VALID_PATHS = VALID_PATHS_WITH_VALUES.merge(VALID_PATHS_WITHOUT_VALUES)
  VALID_PATHS_RE = {
    /[ew][01]/ => /net/
  }

  #
  # Create a new Path (i.e. NodeSetPath instance) for a given NodeSet, or from an already existing Path
  #
  # - obj = a NodeSet or NodeSetPath instance for/from which to create this new instance
  # - newLeaf = optional, add a new leaf to the NodeSetPath (default= nil)
  # - value = optional, set a value to this NodeSetPath (default= nil)
  # - block = optional, a block of command to execute (default= nil)
  #
  def initialize(obj, newLeaf = nil, value = nil, block = nil)
    if obj.kind_of? NodeSetPath
      @nodeSet = obj.nodeSet
      @path = obj.path.clone
    elsif obj.kind_of? NodeSet
      @nodeSet = obj
      @path = Array.new
    else
      raise "Argument needs to be either a NodeSet, or a NodeSetPath, but is #{obj.class.to_s}"
    end

    if value != nil
      #if newLeaf == nil || newLeaf[-1] != ?= 
      if newLeaf == nil 
        path = ""
        @path.each {|p| path = path + '/' +p.to_s}
        raise "Missing assignment operator or argument for path '#{path}/#{newLeaf}'."
        # NOTE: cannot call 'pathString' here cause @pathSubString has not been set yet!
      end
      if newLeaf[-1] != ?=
        newLeaf = newLeaf[0 .. -1]
      else
        newLeaf = newLeaf[0 .. -2]
      end
      @value = value
    end
    if newLeaf != nil
      @path += [newLeaf]
    end

    @pathSubString = @path.join('/')
    super(@pathSubString == "" ? "nodeSetPath" : "nodeSetPath::#{@pathSubString}")
    #debug("Create nodeSetPath '", pathString, "' obj: #{obj.class}")

    if block != nil
      call &block
    end
    if value != nil
      if (@path.last.to_s == "enforce_link")
        @nodeSet.setMACFilteringTable(@path, @value)
        # If this NH is invoked with support for temporary disconnected node/resource, then 
        # do not execute any node/resource configuration commands (this will be done by the
        # slave NH running on the node/resource).
      elsif (NodeHandler.disconnectionMode? == false) 
        @nodeSet.configure(@path, @value)
      end
    # If the path is one that does not require a value (e.g. ip.down or ip.up)
    # then we send a configure command to the nodes
    elsif VALID_PATHS_WITHOUT_VALUES.has_key?(@path.last.to_s)
        @nodeSet.configure(@path, @value)
    end
  end

  #
  # This method calls a block of commands.
  # If the block's arity is 1, this method passes this NodeSetPath instance as the argument to the block.
  # If the block's arity is >1, this method raises an error.
  #
  # - &block = a block of commands
  #
  def call(&block)
    case block.arity
      when -1, 0
        block.call()
      when 1
        block.call(self)
      else
        raise "Block (#{block.arity}) for '" + pathString + "' requires zero, or one argument (|n|)"
    end
  end

  #
  # This method returns the String corresponding to this Path
  #
  # [Return] a String corresponding to this Path
  #
  def pathString()
    @nodeSet.to_s + '/' + @pathSubString
  end

  #
  # This method parses a String describing a sub-Path to this Path, and create a new corresponding NodeSetPath instance.
  # Note: We make use of Ruby's 'method_missing' feature to parse 'x.y.z' into a NodeSetPath 
  #
  # - name = string with the sub-Path to parse
  # - *args = argument given as value to this Path (always 0 or 1 argument, an error is raised if more arguments) 
  # - &block = optional, a block of commands to pass on to the new NodeSetPath instance 
  #
  # [Return] a new NodeSetPath instance corresponding to the parsed String
  #
  def method_missing(name, *args, &block)
    # puts "path(" + pathString + ") " + name.to_s + " @ " + args.to_s + " @ " + (block != nil ? block : nil).to_s
    if args.length > 1
      raise "Assignment to '" + pathString + "/" + name.to_s + "' can only be a single parameter."
    end
    name_s = name.to_s
    re = VALID_PATHS[name_s]
    debug("Testing '#{name}' => '#{@pathSubString}' : #{re}")
    if (re != nil)
      debug("Checking against '#{re}'")
      if (@pathSubString =~ re) != 0
        warn("Unrecognized path '#{@pathSubString}/#{name}'")
      end
    else
      found = false
      VALID_PATHS_RE.each { |nameRe, pattern|
        if (name_s =~ nameRe) == 0
          found = true
          if (@pathSubString =~ pattern) != 0
            warn("Unrecognized path '#{@pathSubString}/#{name}'")
          end
        end
      }
      if ! found
        warn("Unrecognized path '#{@pathSubString}/#{name}'")
      end
    end
    #debug("Creating new nodeSetPath '#{name}'")
    return NodeSetPath.new(self, name_s, args[0], block)
  end

  # 
  #  Set the Flag indicating that this Experiment Controller (NH) is invoked for an 
  #  Experiment that support temporary disconnections
  #       
  def allowDisconnection
    # Check if NH is NOT in 'Slave Mode'
    # When is 'Slave Mode' this mean there is already a Master NH which has its 'disconnection mode' set
    # so we do nothing here
    if !NodeHandler.SLAVE_MODE()
      NodeHandler.setDisconnectionMode()
      @nodeSet.switchDisconnectionON
    end 
  end

end
