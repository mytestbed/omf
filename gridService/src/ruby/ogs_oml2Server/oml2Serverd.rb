#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 - WINLAB, Rutgers University, USA
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
# = oml2Serverd.rb
#
# == Description
#
# This file defines the Oml2ServerDaemon class.
#
require 'ogs/abstractDaemon'

#
# This class implements an interface between the OML2 Service of OMF and the 
# actual oml2 daemon software running on the server. This class is used by 
# the Oml2ServerService class to interact with the oml2 software. 
# Throught its super-class AbstractDaemon, this class not only represent a 
# single Oml2ServerDaemon instance, but it also provides a class-wide array of 
# Oml2ServerDaemon instances currently associated with the OML2 Service.
#
class Oml2ServerDaemon < AbstractDaemon

  # Default IP Address to which this server will bind to
  DEF_ADDRESS = "10.0.0.200"
  # Default path to oml2 server
  DEF_SERVER_BIN = '/usr/sbin/oml2-server'
  # Default debug level to use in logfile
  DEF_SERVER_DEBUG_LEVEL = 4

  # 
  # Set the name of this Oml2ServerDaemon instance. The name is retrieved from 
  # the HTTP request starting this daemon ('id' field in the request) 
  #
  # - req = the HTTP Request used to request the dameon creation
  #
  def self.daemon_name(req)
    name = getDaemonParam(req, 'id')
  end

  attr_reader :daemon_id, :addr, :port, :logFile, :running
  
  #
  # Create a new Oml2ServerDaemon instance. 
  #
  # - req = the HTTP Request used to request the dameon creation
  #
  def initialize(req)
    @daemon_id = self.class.getDaemonParam(req, 'id')
    super(req)
  end

  #
  # Override the default configuration parameter of this Oml2ServerDaemon with 
  # some specific parameters
  #
  # - config = a Hash with the specific parameters to use 
  #
  def configDefaults(config)
    config['serverAddress'] ||= DEF_ADDRESS
    config['serverBin'] ||= DEF_SERVER_BIN
    config['serverDebugLevel'] ||= DEF_SERVER_DEBUG_LEVEL
    raise "File '#{config['serverBin']}' not executable" if !File.executable?(config['serverBin'])
    @addr = config['serverAddress']
  end

  #
  # Return the actual command line that will be used to start the oml2 daemon
  # software, which will be associated to this Oml2ServerDaemon instance.
  # 
  # [Return] a command line (String)
  #
  def getCommand()
    @logFile = "/tmp/#{@daemon_id}.oml2.log"
    cmd = "#{@config['serverBin']} -l #{@port} --logfile=#{@logFile} -d #{@config['serverDebugLevel']}"    
    debug("Exec '#{cmd}'")
    cmd
  end

  #
  # Return a Hash with the settings of this Oml2ServerDaemon instance. 
  # These settings will be used by a client.
  #
  # - parentElement = the original Hash from this method's caller, to which the 
  #                   new Hash with this Oml2ServerDaemon instance will be added.
  #
  # [Return] the 'parentElement' Hash, augmented with this daemon's settings
  #
  def serverDescription(parentElement)
    attr = Hash.new
    attr['id'] = @daemon_id
    attr['logfile'] = @logFile
    attr['timeLeft'] = @untilTimeout
    attr['addr'] = @addr
    attr['port'] = @port
    parentElement.add_element('daemon', attr)
    parentElement
  end

end
