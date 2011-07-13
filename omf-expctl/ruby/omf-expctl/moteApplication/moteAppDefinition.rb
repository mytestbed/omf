#
# Copyright (c) 2006-2010 National ICT Australia (NICTA), Australia
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
# = moteAppDefinition.rb
#
# == Description
#
# This file defines the MoteAppDefinition class
#
#

require 'omf-expctl/application/appDefinition.rb'

#
# Define a new application. The supplied block is
# executed with the new AppDefinition instance
# as a single argument.
#
# - uri =  the URI identifying this new application
# - name = the name of this new application
# - block =  the block to execute
#
def defMoteApplication(uri, name = nil, &block)
  p = MoteAppDefinition.create(uri)
  p.name = name
  block.call(p) if block
end

#
# This class describes a mote application which can be used
# for an experiment using OMF.
#
class MoteAppDefinition < AppDefinition

  # Defining extra attribites on top of the ones defined in Application
  # A mote application has two main executables: One that runs on the 
  # mote (sensor node) and one that runs on the gateway interacting with
  # the mote. The Application attribites "binaryRepository" and "path"
  # are used to give the tar archive of the mote application and the path
  # of the gateway executable respectively. Extra attributes are defined: 
  
  # The name of the executable to be loaded on the mote
  # the file should be found in the binaryRepository
  attr_accessor :moteExecutable
  
  # The name of the executable that will run on the gateway.
  # It is responsible for interpreting the data received
  # from the motes and creating OML structures, as well as
  # receiving commands on its STDIN and converting them to commands
  # to be send to the mote (e.g., for changing a parameter)
  attr_accessor :gatewayExecutable
  
  # The mote type that this application is built. This determines
  # the how the moteExecutable is to be loaded onto the mote.
  attr_accessor :moteType
  
  # The mote OS that is supposed to support this application.
  # This might affect the losding procedure (e.g. for TinyOS we
  # change executable image per mote to hardcore an address) 
  attr_accessor :moteOS
  
  alias :path :gatewayExecutable

  #def initialize(uri)
  #  super(uri)
  #  @path = @gatewayExecutable
  #end

end
