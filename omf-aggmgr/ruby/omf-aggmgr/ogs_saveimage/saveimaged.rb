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
# = saveimaged.rb
#
# == Description
#
# This file defines the SaveimageDaemon class.
#
require 'omf-aggmgr/ogs/abstractDaemon'

#
# This class implements an interface between the Saveimage Service of OMF and the 
# actual netcat instance running on the server. This class is used by 
# the SaveimageService class to interact with netcat. 
# Through its super-class AbstractDaemon, this class does not only represent a 
# single SaveimageDaemon instance, but it also provides a class-wide array of 
# SaveimageDaemon instances currently associated with the Saveimage Service.
#
class SaveimageDaemon < AbstractDaemon

  # 
  # Set the name of this SaveimageDaemon instance.
  #
  # - req = the HTTP Request used to request the daemon creation
  #
  def self.daemon_name(req)
    img = getDaemonParam(req, 'img')
    domain = getDaemonParam(req, 'domain')
    name = domain + '-' + img
  end

  attr_reader :port, :img, :user, :running

  #
  # Create a new SaveimageDameon instance. 
  #
  # - req = the HTTP Request used to request the daemon creation
  #
  def initialize(req)
    @img = self.class.getDaemonParam(req, 'img')
    @user = self.class.getDaemonParam(req, 'user')
    super(req)
  end

  # 
  # Return the netcat listen interface and port
  #
  # [Return] interface:port
  #
  def getAddress()
    "#{@config['saveimageIF']}:#{@port}"
  end

  #
  # Return the actual command line that will be used to start the netcat
  # instance, which will be associated to this SaveimageDameon instance.
  # 
  # [Return] a command line (String)
  #
  def getCommand()
    # check if we have the necessary configuration parameters
    if @config['imageDir'] == nil
      raise HTTPStatus::BadRequest, "Missing configuration 'imageDir'"
    end
    if @config['saveimageIF'] == nil
      raise HTTPStatus::BadRequest, "Missing configuration 'saveimageIF'"
    end
    if @config['ncBin'] == nil
      raise HTTPStatus::BadRequest, "Missing configuration 'ncBin'"
    end
    
    # check for unsafe characters in the image name
    # this is a security measure
    if (@img =~ /[\/\;\:\&\$\|]+/) != nil
      raise HTTPStatus::BadRequest, "Image file name '#{@img}' contains invalid characters"
    end
    
    # check if the image file already exists
    imgPath = "#{@config['imageDir']}/#{@img}"
    if File.exist?(imgPath)
      raise HTTPStatus::BadRequest, "File '#{imgPath}' already exists!"
    end
    
    # check for non-alphanumeric characters in the user name
    # this is a security measure
    if (@user =~ /[\W]+/) != nil
      raise HTTPStatus::BadRequest, "Invalid user name '#{@user}'"
    end
    # do not allow to create images as root
    if @user == 'root'
      raise HTTPStatus::BadRequest, "Sorry, you cannot save files as the superuser (root)."
    end
    
    # check if the user exists locally
    uid = %x[id -u #{@user}]
    if uid.to_i == 0
      debug "User '#{@user}' does not exist on this system!"
      # if the user from the HTTP request doesn't exist on the AM, fall back to the
      # owner given in the config file
      if @config['owner'] == nil
        raise HTTPStatus::BadRequest, "Missing configuration 'owner'"
      else
        @user = @config['owner']
      end
    end
    
    # check for user write permission
    if !system("su #{@user} -c 'touch #{imgPath}'")
      raise HTTPStatus::BadRequest, "User '#{@user}' cannot create file '#{imgPath}'"
    end

    # all good, return the netcat command line
    addr = @config['saveimageIF']
    ncBin = @config['ncBin']
    debug("Starting netcat ('#{ncBin}') as user '#{user}' to receive image '#{imgPath}' on '#{port}' interface '#{addr}'")
    cmd = "su #{user} -c '#{ncBin} -l #{addr} #{port} > #{imgPath}'"
  end

  #
  # Return a Hash with the settings of this SaveimageDaemon instance. 
  # These settings will be used by a client.
  #
  # - parentElement = the original Hash from this method's caller, to which the 
  #                   new Hash with this SaveimageDaemon instance should be added.
  #
  # [Return] the 'parentElement' Hash, augmented with this daemon's settings
  #
  def serverDescription(parentElement)
    attr = Hash.new
    attr['img'] = @img
    attr['user'] = @user
    attr['port'] = @port
    attr['timeLeft'] = "#{self.untilTimeout}"
    parentElement.add_element('daemon', attr)
    parentElement
  end

end
