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
# = pxe.rb
#
# == Description
#
# This file defines the PxeService class.
#

require 'net/http'
require 'omf-aggmgr/ogs/legacyGridService'
require 'omf-aggmgr/ogs/timer'

#
# This class defines a Service to enable/disable one or many node(s) of a
# testbed to boot over the network using the PXE method.
#
# For more details on how features of this Service are implemented below, please
# refer to the description of the AbstractService class
#
class PxeService < LegacyGridService

  # used to register/mount the service, the service's url will be based on it
  name 'pxe'
  description 'Service to facilitate PXE to boot into specific image'
  @@config = nil

  # store the currently installed image for a node identified by its
  # IP address.
  @@nodes = {}

  # keep requests apart
  @@mutex = Mutex.new

  #
  # Implement 'setBootImageNS' service using the 'service' method of AbstractService
  #
  s_description "Get PXE to boot all nodes in 'nodeSet' into their respective PXE image."
  s_param :ns, 'nodeSet', 'set definition of nodes included.'
  s_param :domain, 'domain', 'domain for request.'
  s_param :imgName, '[imageName]', 'Name of the PXE image to use (optional, default image as specified by the Inventory)'
  service 'setBootImageNS' do |req, res|
    ns = getNodeSetParam(req, 'ns')
    tb = getTestbedConfig(req, @@config)
    domain = getParam(req, 'domain')
    imageName = getParamDef(req, 'imgName', nil)
    setImage(ns, tb, domain, res, imageName)
  end

  #
  # Implement 'clearBootImageNS' service using the 'service' method of AbstractService
  #
  s_description "Get PXE to clear the pxe boot image of all nodes in 'nodeSet'"
  s_param :ns, 'nodeSet', 'set definition of nodes included.'
  s_param :domain, 'domain', 'domain for request.'
  service 'clearBootImageNS' do |req, res|
    ns = getNodeSetParam(req, 'ns')
    tb = getTestbedConfig(req, @@config)
    domain = getParam(req, 'domain')
    clearImage(ns, tb, domain, res)
  end

  #
  # Return the PXE Image to use for a specific node on a given testbed. This
  # method makes use of the Inventory GridService
  #
  # - url = URL to the Inventory GridService
  # - hrn = HRN of the node to query
  # - domain = name of the testbed to query
  #
  def self.getPXEImageName(url, hrn, domain)
    queryURL = "#{url}/getPXEImage?hrn=#{hrn}&domain=#{domain}"
    debug "PXE - QueryURL: #{queryURL}"
    response = nil
    response = Net::HTTP.get_response(URI.parse(queryURL))
    if (! response.kind_of? Net::HTTPSuccess)
          error "PXE - No PXE Image info found for #{hrn} - Bad Response from Inventory"
          error "PXE - QueryURL: #{queryURL}"
          raise Exception.new()
    end
    if (response == nil)
      error "PXE - No PXE Image info found for #{hrn} - Response from Inventory is NIL"
      error "PXE - QueryURL: #{queryURL}"
      raise Exception.new()
    end
    doc = REXML::Document.new(response.body)
    # Parse the Reply to retrieve the PXE Image name
    imageName = nil
    doc.root.elements.each("/PXE_Image") { |v|
      imageName = v.get_text.value
    }
    # If no name found in the reply... raise an error
    if (imageName == nil)
      doc.root.elements.each('/ERROR') { |e|
        error "PXE - No PXE Image info found for #{hrn} - val: #{e.get_text.value}"
      }
    end
    return imageName
  end

  #
  # Set some given nodes to network-boot into a specific image via PXE.
  # Following the PXE boot mechanism, this method creates some symlinks to a
  # specific PXE boot image into the '/tftpboot/pxelinux.cfg/' directory of the
  # server hosting the PXE image(s). These symlinks are named based on the
  # Control IP address of the nodes to PXE boot.
  #
  # - nodes = an Array with the HRNs of the nodes to PXE boot
  # - tb = config parameters of the testbed
  # - domain = name of the testbed for these nodes
  # - res = HTTP message that should be returned as a result
  # - image = name of the PXE image to boot
  #
  def self.setImage(nodes, tb, domain, res, image)
    resXml, nodesEl = createResponse('setBootImage')
    inventoryURL = tb['inventory_url']
    cfgDir = @@config['cfgDir']
    nodesHex = []

    @@mutex.synchronize {
      nodes.each {|hrn|
        ip = getControlIP(inventoryURL, hrn, domain)
        if (image == nil)
          img = getPXEImageName(inventoryURL, hrn, domain)
        else
          img = image
        end
        imgPath = "./#{img}"
        hex = ip.split('.').map {|e| format "%02X", e} . join()
        hexPath = "#{cfgDir}/#{hex}"
        if File.readable?(hexPath)
          debug("Remove old #{hexPath}")
          File.delete(hexPath)
        end
        debug("Adding symlink '#{hexPath}' -> '#{imgPath}'")
        @@nodes[hex] = 1 + (@@nodes[hex] || 0)  # increment count
        debug(self, "Requests for node '#{hex}' => #{@@nodes[hex]}")
        nodesHex << hex
        File.symlink(imgPath, hexPath)
        n = nodesEl.add_element('node')
        n.add_attributes({'hrn' => hrn.to_s, 'ip' => ip, 'img' => img, 'hex' => hex})
      }
    }
    Timer.register(nil, @@config['linkLifetime']) {
      @@mutex.synchronize {
        nodesHex.each {|hex|
          debug(self, "Checking node '#{hex}' (#{@@nodes[hex]})")
          if (@@nodes[hex] == 1)
            debug("Clearning PXE for '#{hex}'")
            hexPath = "#{cfgDir}/#{hex}"
            File.unlink(hexPath)
            @@nodes.delete(hex)
          else
            @@nodes[hex] = @@nodes[hex] - 1
          end
        }
      }
    }
    setResponse(res, resXml)
  end

  #
  # Remove PXE boot for some given nodes. At the next reboot, these nodes will
  # boot from their default boot (usually local hardrive).
  # Following the PXE boot mechanism, this method removes the symlinks
  # previously created by setImage(...).
  #
  # - nodes = an Array with the HRNs of the nodes to PXE boot
  # - tb = config parameters of the testbed
  # - domain = name of the testbed for these nodes
  # - res = HTTP message that should be returned as a result
  #
  def self.clearImage(nodes, tb, domain, res)
    resXml, nodesEl = createResponse('clearBootImage')
    inventoryURL = tb['inventory_url']
    cfgDir = @@config['cfgDir']
    nodesHex = []

    @@mutex.synchronize {
      if nodes.length != 0
        nodes.each {|hrn|
          ip = getControlIP(inventoryURL, hrn, domain)
          hex = ip.split('.').map {|e| format "%02X", e} . join()
          hexPath = "#{cfgDir}/#{hex}"
          if File.readable?(hexPath)
            debug("Remove old #{hexPath}")
            File.delete(hexPath)
            debug("Remove old #{hexPath} Done.")
          end
        }
      else
        debug("ClearImage called with an empty nodeSet (#{nodes}), nothing to be done.")
      end
    }
    setResponse(res, resXml)
  end

  #
  # Build a HTTP response, which will be returned by this PXE Service.
  #
  # - actionName = description of the action to use as a response
  #
  # [Return] a pair (res, resXml) holding the basic HTTP response and its XML
  #          extension
  #
  def self.createResponse(actionName)
    root = REXML::Element.new('response')
    root.add_attribute('status', 'OK')
    action = root.add_element('action')
    action.add_attribute('service', 'pxe')
    action.add_attribute('name', actionName)
    nodes = action.add_element('nodes')
    [root, nodes]
  end

  #
  # Configure the service through a hash of options
  #
  # - config = the Hash holding the config parameters for this service
  #
  def self.configure(config)
    @@config = config
    error("Missing configuration 'cfgDir'") if @@config['cfgDir'] == nil
    error("Missing configuration 'defImage'") if @@config['defImage'] == nil
    error("Missing configuration 'linkLifetime'") if @@config['linkLifetime'] == nil
  end

  # RETIRED SERVICES:
  #------------------

  # #
  # # Implement 'setBootImageAll' service using the 'service' method of AbstractService
  # #
  # s_description "Get PXE to boot ALL nodes on this testbed into their respective PXE image"
  # s_param :domain, 'domain', 'domain for request.'
  # s_param :imgName, '[imageName]', 'Name of the PXE image to use (optional, default image as specified by the Inventory)'
  # service 'setBootImageAll' do |req, res|
  #   tb = getTestbedConfig(req, @@config)
  #   inventoryURL = tb['inventory_url']
  #   domain = getParam(req, 'domain')
  #   nodes = listAllNodes(inventoryURL, domain)
  #   imageName = getParamDef(req, 'imgName', nil)
  #   setImage(nodes, tb, domain, res, imageName)
  # end
  # 
  # #
  # # Implement 'clearBootImageAll' service using the 'service' method of AbstractService
  # #
  # s_description "Get PXE to clear the pxe boot image of all nodes"
  # s_param :domain, 'domain', 'domain for request.'
  # service 'clearBootImageAll' do |req, res|
  #   tb = getTestbedConfig(req, @@config)
  #   inventoryURL = tb['inventory_url']
  #   domain = getParam(req, 'domain')
  #   nodes = listAllNodes(inventoryURL, domain)
  #   clearImage(nodes, tb, domain, res)
  # end

end

