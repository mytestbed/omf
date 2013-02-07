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
# = frisbee.rb
#
# == Description
#
# This file defines the FrisbeeService class.
#

require 'omf-aggmgr/ogs/gridService'
require 'omf-aggmgr/ogs_frisbee/frisbeed'

#
# This class defines a Service to control a Frisbee server. A Frisbee server
# is used to distribute disk image in an efficient manner among the nodes of a
# given testbed.
#
# For more details on how features of this Service are implemented below, please
# refer to the description of the AbstractService class
#
class FrisbeeService < GridService

  # used to register/mount the service, the service's url will be based on it
  name 'frisbee'
  description 'Service to control frisbee daemons multicasting image files'
  @@config = nil

  #
  # Implement 'checkImage' service using the 'service' method of AbstractService
  #
  s_description 'Check if a given disk image file exists'
  s_param :domain, '[domain]', 'domain for request.'
  s_param :img, '[img]', 'filename of image to check.'
  s_param :user, '[user]', 'UNIX user name to check image file ownership.'
  service 'checkImage' do |domain, img, user|
    if user.nil?
      return_error("frisbee getAddress: missing 'user' parameter in service call.")
    elsif !safeString?(img)
      return_error("Found unsafe characters in parameter '#{img}'")
    elsif !safeString?(user)
      return_error("Found unsafe characters in parameter '#{user}'")
    else
      tb = getTestbedConfig(domain, @@config)
      img ||= tb['defaultImage']
      imagePath = "#{tb['imageDir']}/#{img}"

      if system("su #{user} -c '[ -f #{imagePath} ] && [ -r #{imagePath} ]'")
        return_ok("Image found and readable")
      else
        return_error("Image file '#{imagePath}' not found or not readable by user '#{user}'")
      end
    end
  end

  #
  # Implement 'getAddress' service using the 'service' method of AbstractService
  #
  s_description 'Get the port number of a frisbee server serving a specified image (start a new server if none exists)'
  s_param :domain, '[domain]', 'domain for request.'
  s_param :img, '[img]', 'name of image to serve [defaultImage].'
  s_param :user, '[user]', 'UNIX user name to check image file ownership.'
  service 'getAddress' do |domain, img, user|
    if user.nil?
      return_error("frisbee getAddress: missing 'user' parameter in service call.")
    elsif !safeString?(img)
      return_error("Found unsafe characters in parameter '#{img}'")
    elsif !safeString?(user)
      return_error("Found unsafe characters in parameter '#{user}'")
    else      
      tb = getTestbedConfig(domain, @@config)
      img ||= tb['defaultImage']
      imagePath = "#{tb['imageDir']}/#{img}"
      d = FrisbeeDaemon.start(:img => "#{img}", :domain => "#{domain}", :user => "#{user}")
      if d.nil?
        return_error("Error serving '#{imagePath}'")
      else
        if d.imageAccessible?(imagePath, user)
          return_ok(d.getAddress())
        else
          return_error("Image file '#{imagePath}' not found or not readable by user '#{user}'")
        end
      end
    end
  end

  #
  # Implement 'stop' service using the 'service' method of AbstractService
  #
  s_description 'Stop serving a specified image'
  s_param :domain, '[domain]', 'domain for request.'
  s_param :img, '[img]', 'name of image to serve [defaultImage].'
  service 'stop' do |domain, img|
    d = FrisbeeDaemon.stop(:img => "#{img}", :domain => "#{domain}")
    if d.nil?
      return_error("Did not stop the frisbeed serving '#{img}'."+
        "Either it is not running or some clients are still receiving data from it." )
    else
      return_ok("Stopped serving '#{img}' at #{d.getAddress()}")
    end
  end

  #
  # Implement 'status' service using the 'service' method of AbstractService
  #
  s_description 'Returns the list of all served images'
  s_param :domain, '[domain]', 'domain for request.'
  s_param :img, '[img]', 'If defined, only report about that image.'
  service 'status' do |domain, img|
    name = FrisbeeDaemon.daemon_name(:img => "#{img}", :domain => "#{domain}")
    list = img == nil ? FrisbeeDaemon.all : [FrisbeeDaemon[name]]   
    if list.empty?
      return_ok("No frisbee daemons are running") 
    elsif list == [nil]
      result = return_ok("No frisbee daemons are currently serving '#{img}'")
    else
      # Build the header of the XML response
      root = REXML::Element.new("frisbee_status")
      root.add_element("bandwidth")
      root.add_element("mc_address")
      bw = Float("#{FrisbeeDaemon.getBandwidth}") / 1000000.0
      root.elements["bandwidth"].text = bw
      root.elements["mc_address"].text = "#{FrisbeeDaemon.getMCAddress}"
      # Build the rest of the XML response
      list.each { |d|
        root = d.serverDescription(root)
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
    FrisbeeDaemon.configure(config)
  end

end



