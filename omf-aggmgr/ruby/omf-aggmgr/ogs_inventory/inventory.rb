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
  description 'Service to retrieve information about nodes or testbeds from the Inventory Database'
  @@config = nil
  @@inventory = nil

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
    if result == :Error
      addXMLElement(root, "ERROR", "Error when accessing the Inventory Database")
    elsif result.nil? or result == [nil] or result == [] or result.empty?
      addXMLElement(root, "ERROR", "#{msg}")
    else
      yield(root, result)
    end
    return root
  end

  #
  # Create new XML reply containing an OK or ERROR message.
  # If result is false, set an error message in this reply.
  # Otherwise return OK.
  #
  # - replyName = name of the new XML Reply object
  # - result = boolean indicating whether the request was successful or not
  # - msg =  the error message to store in this reply, if result is false
  #
  # [Return] a new XML tree
  #
  def self.booleanXMLReply(replyName, result, msg)
    root = REXML::Element.new("#{replyName}")
    if result
      addXMLElement(root, "OK", nil)
    else
      addXMLElement(root, "ERROR", "#{msg}")
    end
    return root
  end

  #
  # Implement 'getPXEImage' service using the 'service' method of AbstractService
  #
  s_description "Get the MAC address of a given interface on a given node for a given domain"
  s_param :hrn, 'hrn', 'HRN of the resource'
  s_param :domain, 'domain', 'testbed/domain for this given node'
  service 'getPXEImage' do |hrn, domain|
    # Retrieve the testbed config
    tb = getTestbedConfig(domain, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getNodePXEImage(hrn, domain)
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      raise HTTPStatus::InternalServerError
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no PXE Image info for node #{hrn} (domain: #{domain})"
    replyXML = buildXMLReply("PXE_IMAGE", result, msgEmpty) { |root,image|
      root.text = image
    }
    replyXML
  end

  #
  # Implement 'getListOfResources' service using the 'service' method of AbstractService
  #
  s_description "Get a list of the HRNs of all available resources on a given domain"
  s_param :domain, 'domain', 'testbed/domain for this query'
  service 'getListOfResources' do |domain|
    tb = getTestbedConfig(domain, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getAllResources(domain)
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      raise HTTPStatus::InternalServerError
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no info for any resources on the domain: #{domain}"
    replyXML = buildXMLReply("RESOURCES", result, msgEmpty) { |root,node|
      node.each { |name|
        addXMLElement(root, "NODE", "#{name}")
      }
    }
    replyXML
  end

  #
  # Implement 'getControlIP' service using the 'service' method of AbstractService
  #
  s_description "Get the Control IP address of a given resource for a given domain"
  s_param :hrn, 'hrn', 'HRN of the resource'
  s_param :domain, 'domain', 'testbed/domain for this given node'
  service 'getControlIP' do |hrn, domain|
    # Retrieve the request parameter
    tb = getTestbedConfig(domain, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getControlIP(hrn, domain)
    rescue Exception => ex
      error "Inventory - getControlIP() - Cannot connect to the Inventory Database - #{ex}"
      result = :Error
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no control IP for HRN '#{hrn}' (domain: #{domain})"
    replyXML = buildXMLReply("CONTROL_IP", result, msgEmpty) { |root,ip|
      root.text = ip
    }
    replyXML
  end
  
  #
  # Implement 'getCmcIP' service using the 'service' method of AbstractService
  #
  s_description "Get the CMC IP address of a given resource for a given domain"
  s_param :hrn, 'hrn', 'HRN of the resource'
  s_param :domain, 'domain', 'testbed/domain for this given node'
  service 'getCmcIP' do |hrn, domain|
    # Retrieve the request parameter
    tb = getTestbedConfig(domain, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getCmcIP(hrn, domain)
    rescue Exception => ex
      error "Inventory - getCmcIP() - Cannot connect to the Inventory Database - #{ex}"
      result = :Error
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no CMC IP for HRN '#{hrn}' (domain: #{domain})"
    replyXML = buildXMLReply("CMC_IP", result, msgEmpty) { |root,ip|
      root.text = ip
    }
    replyXML
  end

  #
  # Implement 'getSwitchPort' service using the 'service' method of AbstractService
  #
  s_description "Get the switch IP address and port of the primary network interface of a node"
  s_param :hrn, 'hrn', 'HRN of the resource'
  s_param :domain, 'domain', 'testbed/domain for this given node'
  service 'getSwitchPort' do |hrn, domain|
    # Retrieve the request parameter
    tb = getTestbedConfig(domain, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getSwitchPort(hrn, domain)
    rescue Exception => ex
      error "Inventory - getSwitchPort() - Cannot connect to the Inventory Database - #{ex}"
      result = :Error
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no switch IP/port for HRN '#{hrn}' (domain: #{domain})"
    replyXML = buildXMLReply("SWITCH_IP_PORT", result, msgEmpty) { |root,port|
      root.text = port
    }
    replyXML
  end
  
  #
  # Implement 'getCmcIP' service using the 'service' method of AbstractService
  #
  s_description "Get the CMC IP address of a given resource for a given domain"
  s_param :hrn, 'hrn', 'HRN of the resource'
  s_param :domain, 'domain', 'testbed/domain for this given node'
  service 'getCmcIP' do |hrn, domain|
    # Retrieve the request parameter
    tb = getTestbedConfig(domain, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getCmcIP(hrn, domain)
    rescue Exception => ex
      error "Inventory - getCmcIP() - Cannot connect to the Inventory Database - #{ex}"
      result = :Error
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no CMC IP for HRN '#{hrn}' (domain: #{domain})"
    replyXML = buildXMLReply("CMC_IP", result, msgEmpty) { |root,ip|
      root.text = ip
    }
    replyXML
  end


  #
  # Implement 'getHRN' service using the 'service' method of AbstractService
  #
  s_description "Get the HRN for a certain hostname on a given domain"
  s_param :hrn, 'hostname', 'hostname of the node'
  s_param :domain, 'domain', 'testbed/domain for this given node'
  service 'getHRN' do |hostname, domain|
    # Retrieve the request parameter
    tb = getTestbedConfig(domain, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getHRN(hostname, domain)
    rescue Exception => ex
      error "Inventory - getHRN() - Cannot connect to the Inventory Database - #{ex}"
      result = :Error
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no HRN for host '#{hostname}' (domain: #{domain})"
    replyXML = buildXMLReply("HRN", result, msgEmpty) { |root,hrn|
      root.text = hrn
    }
    replyXML
  end
  
  #
  # Implement 'getDefaultDisk' service using the 'service' method of AbstractService
  #
  s_description "Get the default disk for a certain HRN on a given domain"
  s_param :hrn, 'hrn', 'hrn of the node'
  s_param :domain, 'domain', 'testbed/domain for this given node'
  service 'getDefaultDisk' do |hrn, domain|
    # Retrieve the request parameter
    tb = getTestbedConfig(domain, @@config)
    # Query the inventory
    result = nil
    begin
      inv = getInv(tb)
      result = inv.getDefaultDisk(hrn, domain)
    rescue Exception => ex
      error "Inventory - getDefaultDisk() - Cannot connect to the Inventory Database - #{ex}"
      result = :Error
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no default disk for HRN '#{hrn}' (domain: #{domain})"
    replyXML = buildXMLReply("disk", result, msgEmpty) { |root,disk|
      root.text = disk 
    }
    replyXML
  end
  
  # the following service calls are mainly used by omf-admin:

  s_description "Get detailed list of nodes defined in the inventory"
  service 'getAllNodes' do
    tb = getTestbedConfig(nil, @@config)
    # Query the inventory
    begin
      inv = getInv(tb)
      result = inv.getAllNodes()
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      raise HTTPStatus::InternalServerError
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no nodes defined"
    replyXML = buildXMLReply("ALLNODES", result, msgEmpty) { |root,nodes|
      nodes.each { |h|
        nl = root.add_element("NODE")
        nl.add_attributes(h)
      }
    }
    replyXML
  end

  s_description "Get list of testbeds defined in the inventory"
  service 'getAllTestbeds' do
    tb = getTestbedConfig(nil, @@config)
    # Query the inventory
    begin
      inv = getInv(tb)
      result = inv.getAllTestbeds()
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      raise HTTPStatus::InternalServerError
    end
    # Build and Set the XML response
    msgEmpty = "Inventory has no testbeds defined"
    replyXML = buildXMLReply("ALLTESTBEDS", result, msgEmpty) { |root,testbeds|
      testbeds.each { |tb|
        addXMLElement(root, "TESTBED", "#{tb}")
      }
    }
    replyXML
  end

  s_description "Add testbed"
  s_param :testbed, 'testbed', 'name of the testbed'
  service 'addTestbed' do |testbed|
    tb = getTestbedConfig(nil, @@config)
    # Query the inventory
    begin
      inv = getInv(tb)
      result = inv.addTestbed(testbed)
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      raise HTTPStatus::InternalServerError
    end
    booleanXMLReply("ADD_TESTBED", result, "Failed to add testbed `#{testbed}` to the inventory.")
  end

  s_description "Edit testbed name"
  s_param :testbed, 'testbed', 'current name of the testbed'
  s_param :name, 'name', 'new name of the testbed'
  service 'editTestbed' do |testbed, name|
    tb = getTestbedConfig(nil, @@config)
    # Query the inventory
    begin
      inv = getInv(tb)
      result = inv.editTestbed(testbed, name)
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      raise HTTPStatus::InternalServerError
    end
    booleanXMLReply("EDIT_TESTBED", result, "Failed to edit testbed `#{testbed}` in the inventory.")
  end

  s_description "Remove testbed"
  s_param :testbed, 'testbed', 'name of the testbed'
  service 'removeTestbed' do |testbed|
    tb = getTestbedConfig(nil, @@config)
    # Query the inventory
    begin
      inv = getInv(tb)
      result = inv.rmTestbed(testbed)
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      raise HTTPStatus::InternalServerError
    end
    booleanXMLReply("REMOVE_TESTBED", result, "Failed to remove testbed `#{testbed}` from the inventory.")
  end

  s_description "Add node"
  s_param :xml, 'xml', 'xml-encoded hash of node parameters'
  service 'addNode' do |xml|
    tb = getTestbedConfig(nil, @@config)
    doc = REXML::Document.new xml
    h = Hash.new
    doc.elements["NODE"].attributes.each{|name,value|
      MObject.debug(name, value)
      h[name]=value
    }
    # Query the inventory
    begin
      inv = getInv(tb)
      result = inv.addNode(h)
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      raise HTTPStatus::InternalServerError
    end
    booleanXMLReply("ADD_NODE", result, "Failed to add node `x` to the inventory.")
  end
  
  s_description "Remove node"
  s_param :node, 'node', 'hostname of the node'
  s_param :testbed, 'testbed', 'name of the testbed the node belongs to'
  service 'removeNode' do |node,testbed|
    tb = getTestbedConfig(nil, @@config)
    # Query the inventory
    begin
      inv = getInv(tb)
      result = inv.rmNode(node, testbed)
    rescue Exception => ex
      error "Inventory - Error connecting to the Inventory Database - '#{ex}''"
      raise HTTPStatus::InternalServerError
    end
    booleanXMLReply("REMOVE_NODE", result, "Failed to remove node `#{node}` from the inventory.")
  end

  #
  # Configure the service through a hash of options
  #
  # - config = the Hash holding the config parameters for this service
  #
  def self.configure(config)
    @@config = config
  end

end
