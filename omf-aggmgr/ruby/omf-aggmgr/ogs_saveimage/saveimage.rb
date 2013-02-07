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
# = saveimage.rb
#
# == Description
#
# This file defines the SaveimageService class.
#

require 'omf-aggmgr/ogs/gridService'
require 'omf-aggmgr/ogs_saveimage/saveimaged'

#
# This class defines a Service to receive node images via netcat. These images are compressed by 'imagezip'
# on the nodes and sent to the AM via a TCP socket.
#
# For more details on how features of this Service are implemented below, please
# refer to the description of the AbstractService class
#
class SaveimageService < GridService

  # used to register/mount the service, the service's url will be based on it
  name 'saveimage'
  description 'Service to control netcat to receive image files'
  @@config = nil

  #
  # Implement 'getAddress' service using the 'service' method of AbstractService
  #
  s_description 'Get the port number of a netcat instance receiving a specified image (start a new instance if none exists)'
  s_param :domain, 'domain', 'domain for request.'
  s_param :img, 'imgName', 'name of image to save.'
  s_param :user, 'user', 'UNIX user name to set image file ownership.'
  service 'getAddress' do |domain, img, user|
    if user.nil?
      return_error("frisbee getAddress: missing 'user' parameter in service call.")
    elsif !safeString?(img)
      return_error("Found unsafe characters in parameter '#{img}'")
    elsif !safeString?(user)
      return_error("Found unsafe characters in parameter '#{user}'")
    else  
      d = SaveimageDaemon.start(:img => "#{img}", :domain => "#{domain}", :user => "#{user}")
      if d.nil?
        return_error("Error starting netcat listener to save to '#{img}'")
      else
        return_ok(d.getAddress())
      end
    end
  end

  #
  # Implement 'stop' service using the 'service' method of AbstractService
  #
  s_description 'Stop receiving a specified image'
  s_param :domain, 'domain', 'domain for request.'  
  s_param :img, 'imgName', 'name of image to save.'
  service 'stop' do |domain, img|
    d = SaveimageDaemon.stop(:img => "#{img}", :domain => "#{domain}")
    if d.nil?
      return_error("Not currently saving to '#{img}'")
    else
      return_ok("Stopped saving to '#{img}' at #{d.getAddress()}")
    end
  end

  #
  # Implement 'status' service using the 'service' method of AbstractService
  #
  s_description 'Returns the list of a certain or all netcat instances'
  s_param :domain, 'domain', 'domain for request.'
  s_param :img, 'imgName', 'name of image to save.'
  service 'status' do |domain, img|
    name = SaveimageDaemon.daemon_name(:img => "#{img}", :domain => "#{domain}")
    list = img == nil ? SaveimageDaemon.all : [SaveimageDaemon[name]]
    if list.empty?
      return_ok("No saveimage (netcat) daemons are running") 
    elsif list == [nil]
      result = return_ok("Not currently saving to '#{img}'")
    else
      # Build the header of the XML response
      root = REXML::Element.new("saveimage_status")
      # Build the rest of the XML response
      list.each { |d|
        root = d.serverDescription(root) if d != nil
      }
      root
    end
  end

  #
  # Configure the service through a hash of options
  #
  # - config = the Hash holding the config parameters for this service
  #
  def self.configure(config)
    @@config = config
    SaveimageDaemon.configure(config)
  end

end
