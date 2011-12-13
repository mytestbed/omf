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

require 'omf-aggmgr/ogs/gridService'
require 'omf-aggmgr/ogs/timer'

#
# This class defines a Service to enable/disable one or many node(s) of a
# testbed to boot over the network using the PXE method.
#
# For more details on how features of this Service are implemented below, please
# refer to the description of the AbstractService class
#
class PxeService < GridService

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
  s_param :domain, 'domain', 'domain for request.'
  s_param :ns, 'nodeSet', 'list of nodes to boot from PXE'
  s_param :imgName, '[imageName]', 'Name of the PXE image to use (optional, default image as specified by the Inventory)'
  service 'setBootImageNS' do |domain, ns, imgName|
    tb = getTestbedConfig(domain, @@config)
    res = setImage(ns.split(","), tb, domain, "OK", imgName)
    res
  end

  #
  # Implement 'clearBootImageNS' service using the 'service' method of AbstractService
  #
  s_description "Prevent the nodes in 'nodeSet' from booting via PXE"
  s_param :domain, 'domain', 'domain for request.'
  s_param :ns, 'nodeSet', 'list of nodes to clear from PXE booting'
  service 'clearBootImageNS' do |domain, ns|
    tb = getTestbedConfig(domain, @@config)
    res = clearImage(ns.split(","), tb, domain, "OK")
    res
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
    cfgDir = @@config['cfgDir']
    nodesHex = []
    
    @@mutex.synchronize {
      nodes.each {|hrn|
        ip = getControlIP(hrn, domain)
        if (image == nil)
          img = getPXEImage(hrn, domain)
        else
          img = image
        end
        imgPath = "./#{img}"
        hex = ip.split('.').map {|e| format "%02X", e} . join()
        hexPath = "#{cfgDir}/#{hex}"
        if File.readable?(hexPath) || File.symlink?(hexPath)
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
            hexPath = "#{cfgDir}/#{hex}"
            if File.readable?(hexPath) || File.symlink?(hexPath)
              debug("Clearing PXE for '#{hexPath}'")
              File.delete(hexPath)
            end
            @@nodes.delete(hex)
          else
            @@nodes[hex] = @@nodes[hex] - 1
          end
        }
      }
    }
    resXml
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
    cfgDir = @@config['cfgDir']
    nodesHex = []

    @@mutex.synchronize {
      if nodes.length != 0
        nodes.each {|hrn|
          ip = getControlIP(hrn, domain)
          hex = ip.split('.').map {|e| format "%02X", e} . join()
          hexPath = "#{cfgDir}/#{hex}"
          if File.readable?(hexPath) || File.symlink?(hexPath)
            debug("Remove old #{hexPath}")
            File.delete(hexPath)
            debug("Remove old #{hexPath} Done.")
          end
        }
      else
        debug("ClearImage called with an empty nodeSet (#{nodes}), nothing to be done.")
      end
    }
    resXml
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

end

