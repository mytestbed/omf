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
# = inventory.rb
#
# == Description
#
# This file defines the InventoryService class.
#

require 'omf-aggmgr/ogs/gridService'
require 'omf-aggmgr/ogs_inventory/mySQLInventory'

#
# This class defines a Service to access inventory information about available
# testbeds and their resources (e.g. nodes, antenna, etc...). For a given
# administrative entity, there is a unique inventory, which holds information
# for multiple testbeds. 
# Example of information stored in the inventory are: address and port for other 
# Services (e.g. 'where to find the Frisbee Service for testbed X'), or location
# info (e.g. 'where resource Y of testbed X is physically located'), or resource
# specific attributs (e.g. 'what is the MAC address of wireless device I on
# resource Y of testbed X' or 'what is the Control IP of node Y of testbed X').
# The information contained in the inventory should be kept up to date by the 
# testbed operator. The database schema for the OMF-understandable inventory is 
# available in the separate OMF Installation Guide document.
#
# For more details on how features of this Service are implemented below, please
# refer to the description of the AbstractService class
#
#
class InventoryService < GridService

  # used to register/mount the service, the service's url will be based on it
  name 'inventory' 
  info 'Service to retrieve information about nodes or testbeds from the Inventory Database'
  @@config = nil
  @@inventory = nil
  # These are the current configuration parameters available for testbeds running OMF
  CONST_CONFIG_KEYS = [ 'x_max', 'y_max', 'pxe_url', 'cmc_url', 
                        'frisbee_url', 'frisbee_default_disk', 'saveimage_url', 'oml_url']
 
  # From Winlab, please fix/clean 
  #
  #@@device_description = Hash.new("UNKNOWN")
  # XXX This needs to move into the config file.
  #@@device_description["5772 19"] = "Atheros Communications, Inc. AR5212 802.11abg NIC (rev 01)"
  #@@device_description["32904 16931"] = "Intel Corporation PRO/Wireless 2915ABG Network Connection (rev 05)"
  #@@device_description["4332 33157"] = "ZyXEL G (rev 03)"

  #
  # Return a unique interface to the inventory database
  #
  # - inventoryConfig = a Hash with the config setting for this Inventory Service
  #
  # [Return] the instance of the interface to the inventory database
  #
  def self.getInv(inventoryConfig)
    # Just reuse it if it already exist
    inv = @@inventory
    if ( inv == nil )
      # Otherwise create it
      inv = @@inventory = MySQLInventory.new(inventoryConfig['host'],
                                             inventoryConfig['user'],
                                             inventoryConfig['password'],
                                             inventoryConfig['database'])
    end
    inv
  end

  #
  # Create new XML element and add it to an existing XML tree
  #
  # - parent = the existing XML tree to add the new element to
  # - name = the name for the new XML element to add
  # - value =  the value for the new XML element to add
  #
  def self.addXMLElement(parent, name, value)
     el = parent.add_element(name)
     el.add_text(value)
  end

  #
  # Create new XML reply containing a given result value.
  # If the result is 'nil' or empty, set an error message in this reply.
  # Otherwise, call a block of commands to format the content of this reply 
  # based on the result.
  #
  # - replyName = name of the new XML Reply object
  # - result = the result to store in this reply
  # - msg =  the error message to store in this reply, if result is nil or empty
  # - &block = the block of command to use to format the result
  #
  # [Return] a new XML tree 
  #  
  def self.buildXMLReply(replyName, result, msg, &block)
    root = REXML::Element.new("#{replyName}")
    if (result == :Error)
      addXMLElement(root, "ERROR", "Error when accessing the Inventory Database")
    elsif (result == nil || result.empty?)
    addXMLElement(root, "ERROR", "#{msg}")
    else
      yield(root, result)
    end
    return root
  end

  #
  # Implement 'getMacAddress' service using the 'service' method of AbstractService
  #
  s_info "Get the MAC address of a given interface on a given node for a given domain"
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  s_param :ifname, 'interfaceName', 'name of the interface (e.g. ath0).'
  s_param :domain, 'domain', 'testbed/domain for this given node'
  service 'getMacAddress' do |req, res|
    # Retrieve the request parameter
    x = getParam(req, 'x')
    y = getParam(req, 'y')
    ifname = getParam(req, 'ifname')
    domain = getParam(req, 'domain')
    tb = getTestbedConfig(req, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getMacAddrByName(x, y, ifname, domain)
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      return :Error
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no info on [#{ifname}] for node [#{x},#{y}] (domain: #{domain})"
    replyXML = buildXMLReply("MAC_Address", result, msgEmpty) { |root,mac|
      addXMLElement(root, "#{ifname}", "#{mac}")
    }
    setResponse(res, replyXML)
  end
  
  #
  # Implement 'getPXEImage' service using the 'service' method of AbstractService
  #
  s_info "Get the MAC address of a given interface on a given node for a given domain"
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  s_param :domain, 'domain', 'testbed/domain for this given node'
  service 'getPXEImage' do |req, res|
    # Retrieve the request parameter
    x = getParam(req, 'x')
    y = getParam(req, 'y')
    domain = getParam(req, 'domain')
    tb = getTestbedConfig(req, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getNodePXEImage(x, y, domain)
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      return :Error
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no PXE Image info for node [#{x},#{y}] (domain: #{domain})"
    replyXML = buildXMLReply("PXE_Image", result, msgEmpty) { |root,image|
      root.text = image
    }
    setResponse(res, replyXML)
  end

  #
  # Implement 'getAllMacAddresses' service using the 'service' method of AbstractService
  #
  s_info "Get the MAC addresses of all the interfaces on a given node on a given domain"
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  s_param :domain, 'domain', 'testbed/domain for this given node'
  service 'getAllMacAddresses' do |req, res|
    # Retrieve the request parameter
    x = getParam(req, 'x')
    y = getParam(req, 'y')
    domain = getParam(req, 'domain')
    tb = getTestbedConfig(req, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getAllMacAddr(x, y, domain)
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      return :Error
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no info for interfaces of node [#{x},#{y}] (domain: #{domain})"
    replyXML = buildXMLReply("MAC_Address", result, msgEmpty) { |root,macs|
      macs.each { |couple|
        addXMLElement(root, "#{couple[0]}", "#{couple[1]}")
      }
    }
    setResponse(res, replyXML)
  end

  #
  # Implement 'getControlIP' service using the 'service' method of AbstractService
  #  
  s_info "Get the Control IP address of a given node for a given domain"
  s_param :x, 'xcoord', 'x coordinates of location'
  s_param :y, 'ycoord', 'y coordinates of location'
  s_param :domain, 'domain', 'testbed/domain for this given node'
  service 'getControlIP' do |req, res|
    # Retrieve the request parameter
    x = getParam(req, 'x')
    y = getParam(req, 'y')
    domain = getParam(req, 'domain')
    tb = getTestbedConfig(req, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getControlIP(x, y, domain)
    rescue Exception => ex
      error "Inventory - getControlIP() - Cannot connect to the Inventory Database - #{ex}"
      result = :Error
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no control IP for node [#{x},#{y}] (domain: #{domain})"
    replyXML = buildXMLReply("CONTROL_IP", result, msgEmpty) { |root,ip|
      root.text = ip
    }
    setResponse(res, replyXML)
  end

  #
  # Implement 'getConfig' service using the 'service' method of AbstractService
  # 
  s_info "Get all Specific Configuration Parameters for a given Testbed"
  s_param :domain, 'domain', 'domain for which we want to retrieve the config parameters.'
  service 'getConfig' do |req, res|
    # Retrieve the request parameter
    domain = getParam(req, 'domain')
    tb = getTestbedConfig(req, @@config) # This is GS config, not NH configs!
    rootXMLConfig = REXML::Element.new("CONFIG")
    inv = getInv(tb)
    CONST_CONFIG_KEYS.each { |k|
      # Query the inventory
      result = nil
      begin
        result = inv.getConfigByKey(k, domain)
      rescue Exception => ex
        error "Inventory - getConfigFromInventory() - Cannot connect to the Inventory Database - #{ex}"
        result = :Error
      end
      msgEmpty = "Inventory has no info on [#{k}] for domain: #{domain}"
      replyXML = buildXMLReply("#{k}", result, msgEmpty) { |root,value|
        root.text = value
      }
      rootXMLConfig.add_element(replyXML)
    }
    setResponse(res, rootXMLConfig)
  end
  
  #
  # Implement 'getAllWirelessDevices' service using the 'service' method of AbstractService
  # NOTE: Following code added by Winlab?, not sure if it is still used... 
  #       if so it might need some fixing with new way of handling access to 
  #       inventory. 
  #
  s_info "Get list of wireless devices on a given node in a given domain."
  s_param :x, 'xcoord', 'x coordinate of given node'
  s_param :y, 'ycoord', 'y coordinate of given node'
  s_param :domain, 'domain', 'domain of given node'
  service 'getAllWirelessDevices' do |req, res|
    x = getParam(req, 'x')
    y = getParam(req, 'y')
    domain = getParam(req, 'domain')
    tb = getTestbedConfig(req, @@config)
    ids = getAllWirelessDevices(tb, x, y, domain)
    root = REXML::Element.new("device")
    if (ids == :Error)
      # XXXXXXX Wow.  We can't 404?
      root.add_element("ERROR")
      root.elements["ERROR"].text = "Error when accessing the Inventory Database."
    elsif (ids.empty?)
      root.add_element("ERROR")
      root.elements["ERROR"].text = "No information for node [#{x},#{y}] (domain: #{domain})."
    else
      ids.each { | triple |
        # destructuring bind? anyone? Buler?
        ix = triple[0]
        v = triple[1]
        d = triple[2]
        root.add_element(ix)
        root.elements[ix].add_attribute("vendor", v)
        root.elements[ix].add_attribute("device", d)
        root.elements[ix].text = @@device_description["#{v} #{d}"]
      }
    end
    setResponse(res, root)
  end

  #
  # Implement 'getAllNodesWithOui' service using the 'service' method of AbstractService
  # NOTE: Following code added by Winlab?, not sure if it is still used... 
  #       if so it might need some fixing with new way of handling access to 
  #       inventory. 
  #
  s_info "Get list of nodes that have network cards with given OUI (first 3 bytes) on a given domain"
  s_param :oui, 'oui', 'First three bytes of the OUI as B1:B2:B3'
  s_param :domain, 'domain', 'domain for this node list'
  service 'getAllNodesWithOui' do |req, res|
    oui = getParam(req, 'oui')
    domain = getParam(req, 'domain')
    root = REXML::Element.new("nodes")
    begin
      tb = getTestbedConfig(req, @@config)
      inv = getInv(tb)
      nodes =  inv.getNodesWithOUIInterfaces(oui, domain)
      if (nodes.empty?)
        root.add_element("ERROR")
        root.elements["ERROR"].text = "No nodes with oui: #{oui} (domain: #{domain})."
      else
        nodes.each { | coords |
          el = root.add_element("node")
          el.add_attribute("x", coords[0])
          el.add_attribute("y", coords[1])
        }
      end
    rescue Exception => ex
      root.add_element("ERROR")
      root.elements["ERROR"].text = "Error when accessing the Inventory Database."
    end
    setResponse(res, root)
  end

  #
  # Implement 'getAllDeviceAliases' service using the 'service' method of AbstractService
  # NOTE: Following code added by Winlab?, not sure if it is still used... 
  #       if so it might need some fixing with new way of handling access to 
  #       inventory. 
  #
  s_info "Get list of device aliases defined in the inventory"
  s_param :domain, 'domain', 'domain for the alias list'
  service 'getAllDeviceAliases' do |req, res|
    MObject::debug("In get Aliases")
    root = REXML::Element.new("result")
    begin
      tb = getTestbedConfig(req, @@config)
      inv = getInv(tb)
      aliases =  inv.getDeviceAliases()
      MObject::debug("Got the list")
      if (aliases.empty?)
        root.add_element("ERROR")
        root.elements["ERROR"].text = "Empty alias list"
      else
        aliasnode = root.add_element("aliases")
        aliases.each { | al |
          el = aliasnode.add_element("alias")
          el.add_attribute("name", al)
        }        
      end
    rescue Exception => ex
      root.add_element("ERROR")
      root.elements["ERROR"].text = "Error when accessing the Inventory Database."
    end
    setResponse(res, root)
  end

  #
  # Implement 'getAllNodesWithAliasDevice' service using the 'service' method of AbstractService
  # NOTE: Following code added by Winlab?, not sure if it is still used... 
  #       if so it might need some fixing with new way of handling access to 
  #       inventory. 
  #  
  s_info "Get list of nodes that have devices with the human readable alias (tag)"
  s_param :alias, 'alias', 'Device alias (tag)'
  s_param :domain, 'domain', 'domain for this node list'
  service 'getAllNodesWithAliasDevice' do |req, res|
    tag = getParam(req, 'alias')
    domain = getParam(req, 'domain')
    root = REXML::Element.new("InventoryReport")
    root.add_attribute("querry", "getAllNodesWithAliasDevice")
    root.add_attribute("alias",tag)
    begin
      tb = getTestbedConfig(req, @@config)
      inv = getInv(tb)
      MObject::debug("Opened database")
      range = inv.getNodeCoordinateRange(domain)
      nodes = inv.getNodesWithTagInterfaces(tag, domain)
      MObject::debug("Got inventory req for #{tag} (domain: #{domain}).")
      if (nodes.empty?)
        root.add_element("ERROR")
        root.elements["ERROR"].text = "No nodes with tag: #{tag} (domain: #{domain})."
      else
        MObject::debug("Got #{range[0]}, #{range[1]}, #{range[2]}")
        addXMLElement(root,"domain",domain)
        nl = root.add_element("range")        
        addXMLElement(nl,"x_max",range[0])
        addXMLElement(nl,"y_max",range[1])
        addXMLElement(nl,"z_max",range[2])
        ndetail = root.add_element("detail")
        nlist = root.add_element("nodeArray")
        nlist.add_text '['
        nodes.each { | coords |
          el = ndetail.add_element("node")
          el.add_attribute("x", coords[0])
          el.add_attribute("y", coords[1])
          nlist.add_text "[#{coords[0]},#{coords[1]}]"
          if (coords != nodes.last) 
            nlist.add_text ','
          end
        }
        nlist.add_text ']'
      end
    rescue Exception => ex
      root.add_element("ERROR")
      root.elements["ERROR"].text = "Error when accessing the Inventory Database -> #{ex}"
    end
    setResponse(res, root)
  end
  
  #
  # Return all the Wireless Devices for a given resource of a given testbed.
  # NOTE: Following code added by Winlab?, not sure if it is still used... 
  #       if so it might need some fixing with new way of handling access to 
  #       inventory. 
  #
  def self.getAllWirelessDevices(tbConfig, x, y, domainName)
    h = tbConfig['host']
    u = tbConfig['user']
    p = tbConfig['password']
    d = tbConfig['database']
    begin
      inv = MySQLInventory.new(h, u, p, d)
      inv.open()
    rescue Exception => ex
      error "Inventory - getAllWirelessDevices() - Cannot connect to the Inventory Database #{d} on #{h} as #{u} - #{ex}"
      return :Error
    end
    wds = inv.getAllPCIID(x, y, domainName)
    inv.close()
    return wds
  end
  
  #
  # Configure the service through a hash of options
  #
  # - config = the Hash holding the config parameters for this service
  #
  def self.configure(config)
    @@config = config
  end
  
  #
  # Easter Egg :-)
  #
  s_info "This service has meta cow powers"
  service 'moo' do |req, res|
    # Moo.
    root = REXML::Element.new("moo")
    root.text = <<MOO_MOO_MOO

 ________
( lambda )
 --------
        o   ^__^
         o  (oo)\\_______
            (__)\\       )\\/\\
                ||----w |
                ||     ||

Do not go big.  Do not go small.  Go meta.
MOO_MOO_MOO
    setResponse(res, root)
  end
end
