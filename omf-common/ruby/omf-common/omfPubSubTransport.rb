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
# = omfPubSubTransport.rb
#
# == Description
#
# This file implements a generic Publish/Subscribe transport to be used by the 
# various OMF entities.
#
require "omf-common/omfXMPPServices"
require "omf-common/omfCommandObject"
require 'omf-common/mobject'

# 
# This class defines a generic PubSub Transport  
# Currently, this PubSub Transport is done over XMPP, and this class is using
# the third party library XMPP4R.
# OMF Entities should subclass this class to customise their transport with 
# their specific send/receive pre-processing tasks.
#
class OMFPubSubTransport < MObject

  @@instance = nil

  # Names for constant PubSub nodes
  DOMAIN = "OMF"
  RESOURCE = "resources"
  SYSTEM = "system"
  DEFAULT_PUBSUB_PWD = "123456"
  RETRY_INTERVAL = 10

  def slice_node(slice)
    "/#{DOMAIN}/#{slice}"
  end

  def exp_node(slice, experiment)
    "#{slice_node(slice)}/#{experiment}"
  end

  def res_node(slice, resource = nil)
    if resource == nil
      "#{slice_node(slice)}/#{RESOURCE}"
    else
      "#{resources_node(slice)}/#{resource}"
    end
  end

  def sys_node(resource = nil)
    if resource == nil
      "/#{DOMAIN}/#{SYSTEM}"
    else
      "#{system_node}/#{resource}"
    end
  end

  def sys_node?(node_name)
    if node_name =~ /#{system_node}\/(.*)/ then
      $1
    else
      nil
    end
  end

  def self.instance
    @@instance
  end

  def self.init
    raise "PubSub Transport already started" if @@instance
    @@instance = self.new
    @@queue = Queue.new
    Thread.new {
      while event = @@queue.pop
        execute_command(event)
      end
    }
  end

  #
  # This method instantiates a PubSub Service Helper, which will connect to the
  # PubSub server, and handle all the communication from/towards this server.
  # This method also sets the callback method, which will be called upon incoming
  # messages. 
  #
  # - jid_suffix = [String], JabberID suffix, this is the full host/domain name of 
  #                the PubSub server, e.g. 'norbit.npc.nicta.com.au'. 
  # - password = [String], password to use for this PubSud client
  # - control_interface = [String], the interface connected to Control Network
  #
  def connect(user, pwd, server)  
    # Open a connection to the Home PubSub Server
    begin
      debug "Connecting to PubSub Server '#{server}' as user '#{user}'"
      @@xmppServices = OmfXMPPServices.new(user, pwd, server)
    rescue Exception => ex
      error "Failed to connect to Home PubSub Server '#{server}'!"
      error "Error: '#{ex}'"
      exit
    end
    # Create a new Service to interact with our Home PubSub Server
    # When a new event comes from that server, we push it on our event queue
    @@xmppServices.add_new_service(:home, server) { |event|
      @@queue << event
    }         
  end


  #
  # Return a Command Object which will hold all the information required to send
  # a command to another OMF entity.
  # This PubSub transport uses the OmfCommandObject class as the Command Object
  # to return
  #
  # - type = the type of this Command Object
  #
  # [Return] an OmfCommandObject of the specified type
  #
  def new_command(type)
    return OmfCommandObject.new(type)
  end

  #
  # Send a command to one or multiple Pubsub nodes. 
  # The command to send is passed as an OmfCommandObject.
  # Subclasses MUST override this class to do some subclass-specififc tasks
  # before sending the command. Typically, the OMF EC and RC MUST do that.
  #
  # - cmdObj = the Command Object to format and send
  #
  # Refer to the OmfCommandObject class for a full description of the possible
  # attributes of a Command Object.
  #
  def send_command(cmdObject)
    raise unimplemented_method_exception("send_command")
  end

  def execute_command(cmdObject)
    raise unimplemented_method_exception("execute_command")
  end

  #
  # Send an XML message to a given PubSub destination node
  #
  # - message = [REXML::Document] the message to send
  # - dst = [String] the pubsub node to send the message to 
  # - serviceID = [String] ID of pubsub server hosting the node to send to 
  #
  def send(message, dst, pubsubService)
    # Sanity checks...
    if (message == nil) || (message.length == 0) 
      error "send - Ignore attempt to send an empty message"
      return
    end
    if (dst == nil) || (dst.length == 0 ) 
      error "send - Ignore attempt to send message to nobody"
      return
    end
    # Build Message
    item = Jabber::PubSub::Item.new
    msg = Jabber::Message.new(nil, message)
    item.add(msg)
    # Send it
    debug("send - Send to '#{dst}' - msg: '#{message}'")
    begin
      @@xmppServices.publish_to_node("#{dst}", item, serviceID)        
    rescue Exception => ex
      error "Failed sending to '#{dst}' on '#{serviceID}'"
      error "Failed msg: '#{message}'"
      error "Error msg: '#{ex}'"
    end
  end

  def check_server_reachability(server)
    check = false
    while !check
      reply = `ping -c 1 #{server}`
      if $?.success?
        check = true
      else
        info "Could not resolve or contact: '#{server}'"+ 
	      "Waiting #{RETRY_INTERVAL} sec before retrying..."
        sleep RETRY_INTERVAL
      end
    end
  end


  def unimplemented_method_exception(method_name)
    "PubSubTransport - Subclass '#{self.class}' must implement #{method_name}()"
  end


end

