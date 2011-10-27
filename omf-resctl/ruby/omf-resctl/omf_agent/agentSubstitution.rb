#
# Copyright (c) 2006-2011 National ICT Australia (NICTA), Australia
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
# = agentSubstitution.rb
#
# == Description
#
# This file contains all the types of substitutions that this agent can 
# perform on any commands received from the Experiment Controller.
#
# How substitution work:
# - when the agent receives a command wich contains a string of the form %key%
# - it subsitutes that string with another string dynamically built by that agent
#
# How does this agent recognise a 'key' to substitue and does the job?
# - for each 'key' there should be a method defined below with the same name
# - this defined method should have the necessary code to build the substitute string
#
# See the simple 'index' and 'hostname' examples below
#
# Note: in the methods below, the parameter 'controller' is a handle on the agent 
# itself, so that your own substitution method can access the agent's attributes and
# methods to build your own substitute string

# Substitute '%index%' with the unique index number that was assigned to this agent
def index(controller)
  return controller.index
end

# Substitute '%hostname%' with the hostname of this agent as given by /bin/hostname
def hostname(controller)
  return `/bin/hostname`.chomp
end

# FOR WINLAB...
#
# Substitute '%x%' by the X coordinate of this agent's node
# Substitute '%y%' by the Y coordinate of this agent's node
# Assumptions: 
# - this agent's control interface has been set in its YAML config file
# - the corresponding IP is of the form: AAA.BBB.x.y 
# (e.g. 10.11.1.1 for node1-1 on interface eth1 on sandbox1 at WINLAB)
def x(controller)
  return controller.controlIP.split('.')[2]
  #return `/sbin/ifconfig control`.split("\n")[1].split('addr:')[1].split[0].split('.')[2]
end
def y(controller)
  return controller.controlIP.split('.')[3]
  #return `/sbin/ifconfig control`.split("\n")[1].split('addr:')[1].split[0].split('.')[3]
end
