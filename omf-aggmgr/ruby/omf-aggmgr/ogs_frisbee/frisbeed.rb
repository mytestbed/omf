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
#
#
# = frisbeed.rb
#
# == Description
#
# This file defines the FrisbeeDaemon class.
#
require 'ogs/abstractDaemon'

#
# This class implements an interface between the Frisbee Service of OMF and the 
# actual frisbee daemon software running on the server. This class is used by 
# the FrisbeeService class to interact with the frisbee software. 
# Throught its super-class AbstractDaemon, this class not only represent a 
# single FrisbeeDaemon instance, but it also provides a class-wide array of 
# FrisbeeDaemon instances currently associated with the Frisbee Service.
#
class FrisbeeDaemon < AbstractDaemon

  # 
  # Set the name of this FrisbeeDaemon instance. The name is derived from the
  # HTTP request starting this daemon, and is formed of: 
  # 'domainName' + ( 'imageNme' || '')
  #
  # - req = the HTTP Request used to request the dameon creation
  #
  def self.daemon_name(req)
    img = getDaemonParamDef(req, 'img', nil)
    domain = getDaemonParam(req, 'domain')
    name = domain + (img || '')
  end

  attr_reader :port, :img, :running

  # 
  # Return the bandwidth for this FrisbeeDaemon instance
  #
  # [Return] a bandwidth value
  #
  def self.getBandwidth()
    @@bw
  end
  
  # 
  # Return the multicast address used by this FrisbeeDaemon instance
  #
  # [Return] a multicast address
  #  
  def self.getMCAddress()
    @@mcAddr
  end

  #
  # Create a new FrisbeeDameon instance. 
  #
  # - req = the HTTP Request used to request the dameon creation
  #
  def initialize(req)
    @img = self.class.getDaemonParamDef(req, 'img', nil)
    super(req)
    @@bw = @config['bandwidth']
    @@mcAddr = @config['mcAddress']
  end

  #
  # Return the full 'address:port' used by this FrisbeeDaemon instance
  #
  def getAddress()
    "#{@mcAddress}:#{@port}"
  end

  #
  # Return the actual command line that will be used to start the frisbee daemon
  # software, which will be associated to this FrisbeeDameon instance.
  # 
  # [Return] a command line (String)
  #
  def getCommand()
    @img ||= @config['defaultImage']
    imgPath = "#{@config['imageDir']}/#{@img}"
    if ! File.readable?(imgPath)
      raise HTTPStatus::BadRequest, "Image file '#{imgPath}' not found"
    end

    addr = @config['multicastIF']
    frisbeed = @config['frisbeeBin']
    @mcAddress = @config['mcAddress']
    bw = @config['bandwidth']
    debug("Starting frisbeed ('#{frisbeed}') for '#{img}' on '#{port}' interface '#{addr}'")
    cmd = "#{frisbeed} -i #{addr} -m #{@mcAddress} -p #{port} -W #{bw} #{imgPath}"
  end

  #
  # Return a Hash with the settings of this FrisbeeDaemon instance. 
  # These settings will be used by a client.
  #
  # - parentElement = the original Hash from this method's caller, to which the 
  #                   new Hash with this FrisbeeDaemon instance should be added.
  #
  # [Return] the 'parentElement' Hash, augmented with this daemon's settings
  #
  def serverDescription(parentElement)
    attr = Hash.new
    attr['img'] = @img
    attr['port'] = @port
    attr['timeLeft'] = "#{self.untilTimeout}"
    parentElement.add_element('daemon', attr)
    parentElement
  end

end
