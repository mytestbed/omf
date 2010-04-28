#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia

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
# = mySQLInventory.rb
#
# == Description
#
# This file defines the MySQLInventory class.
#

require 'mysql' # Always use the latest 'default' MySQL Ruby library (we need 'reconnect' flag support)
require 'set'

#
# This class implements an interface to the MySQL database which holds the
# Inventory information for the available testbeds. This class is used by the
# Inventory GridServices as a 'query engine' over the MySQL database.
# Some specific queries to the Inventory have their methods implemented here.
#
# NOTE: this class opens a connection to the MySQL database, with the
# MySQL 'reconnect' set to true. Only one connection to the database exists at
# anytime, re-connection occurs automatically after the default MySQL idle
# timeout. Therefore, this class requires a recent MySQL Ruby Library (support
# 'reconnect' flag).
#
class MySQLInventory < MObject

  #
  # Create a new MySQLInventory instance
  #
  # - host = address of the MySQL server hosting the Inventory database
  # - user = user name to access this database
  # - password = password to access this database
  # - database = name of the database (default = inventory)
  #
  def initialize(host, user, password, database = "inventory")
    @my   = nil
    @host  = host
    @user  = user
    @pw    = password
    @db    =  database
    open()
  end

  #
  # Open a connection to the MySQL Server, using the parameters given when this
  # MySQLInventory was created, see initialize(...).
  #
  def open()
    begin
      @my = Mysql.connect(@host, @user, @pw, @db)
      # Set the MySQL 'reconnect' flag -> Connection to the database will be
      # automatically maintained even if the Server closes it due to timed-out idle period
      @my.reconnect = true
      debug " -  Open Connection to MYSQL server - reconnect=#{@my.reconnect}"
    rescue MysqlError => e
      debug "SQL error message: #{e.error}."
    end
  end

  #
  # Close a previously opened connection to the MySQL server
  #
  def close()
    @my.close()
    @my = nil
  end

  #
  # Run a given Query against the MySQL Inventory database, and execute a given
  # block of command on the result of this query
  #
  # - query = a String with the MySQL query to run
  # - &block = the block of command, which will process the result of this query
  #
  def runQuery(query, &block)
    begin
      debug "SQL Query: '#{query}'"
      reply=@my.query(query)
      # Check if the SQL result contains anything at all...
      # If so, then call the block of commands to process it
      if (reply.num_rows() > 0)
        reply.each() { |result|
          debug "SQL Reply: '#{result.to_s}'"
          yield(result)
        }
      else
        debug "SQL Reply is EMPTY!"
      end
    rescue MysqlError => e
      debug "ERROR - SQL Error: '#{e}'"
    end
  end

  #
  # Query the Inventory database for the Control IP address of a specific node
  # on a testbed.
  #
  # - hrn = HRN of the node to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] the Control IP address of the node matching the query
  #
  def getControlIP(hrn, domain = "grid")
    qs = <<CONTROL_QS
SELECT nodes.control_ip
  FROM nodes
  LEFT JOIN locations ON nodes.location_id = locations.id
  LEFT JOIN testbeds ON locations.testbed_id = testbeds.id
WHERE testbeds.node_domain='#{domain}'
  AND nodes.hrn='#{hrn}';
CONTROL_QS

    addr = nil
    runQuery(qs) { |ip|
      addr = ip
    }
    return addr
  end

    #
    # Query the Inventory database for the Control IP address of a specific node
    # on a testbed.
    #
    # - hostname = hostname of the node to query
    # - domain = name of the testbed to query (default=grid)
    #
    # [Return] the HRN of the node matching the query
    #
    def getHRN(hostname, domain = "grid")
      qs = <<HRN_QS
SELECT nodes.hrn
  FROM nodes
  LEFT JOIN locations ON nodes.location_id = locations.id
  LEFT JOIN testbeds ON locations.testbed_id = testbeds.id
WHERE testbeds.node_domain='#{domain}'
  AND nodes.hostname='#{hostname}';
HRN_QS

      addr = nil
      runQuery(qs) { |ip|
        addr = ip
      }
      return addr
    end

  #
  # Query the Inventory database for the MAC address corresponding to a
  # specific interface name of a given node on a testbed.
  #
  # - x,y = coordinate of the node to query
  # - cname = name of the interface to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] the MAC address of the interface on the node matching the query
  #
  def getMacAddrByName(x, y, cname = "ath0", domain = "grid")
    qs = <<MAC_QS
SELECT devices.mac
  FROM devices
  LEFT JOIN nodes ON devices.motherboard_id = nodes.motherboard_id
  LEFT JOIN locations ON nodes.location_id = locations.id
  LEFT JOIN testbeds ON locations.testbed_id = testbeds.id
WHERE testbeds.node_domain='#{domain}'
  AND locations.x=#{x}
  AND locations.y=#{y}
  AND canonical_name='#{cname}';
MAC_QS

    addr = nil
    runQuery(qs) { |mac|
      addr = mac
    }
    return addr
  end

  #
  # Query the Inventory database for all MAC addresses corresponding to all
  # the interfaces of a given node on a testbed.
  #
  # - x,y = coordinate of the node to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] a Set with the MAC address of the interfaces on the node matching
  #          the query
  #
  def getAllMacAddr(x, y, domain = "grid")
  qs = <<ALLMAC_QS
SELECT devices.mac , devices.canonical_name
  FROM devices
  LEFT JOIN nodes ON devices.motherboard_id = nodes.motherboard_id
  LEFT JOIN locations ON nodes.location_id = locations.id
  LEFT JOIN testbeds ON locations.testbed_id = testbeds.id
WHERE testbeds.node_domain='#{domain}'
  AND locations.x=#{x}
  AND locations.y=#{y};
ALLMAC_QS

    addr = Set.new
    runQuery(qs) { |mac, cnm|
      couple = [cnm, mac]
      addr.add(couple)
    }
    return addr
  end

  #
  # Query the Inventory database for a specific configuration parameter of a
  # given testbed
  #
  # - key = name of the configuration parameter to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] the value of the configuration parameter matching the query
  #
  def getConfigByKey(key, domain = "grid")
    qs = <<CONFIG_Q
SELECT testbeds.#{key}
  FROM testbeds
WHERE testbeds.node_domain='#{domain}';
CONFIG_Q

    value = nil
    runQuery(qs) { |v|
      value = v
    }
    return value
  end

  #
  # Query the Inventory database for the name of the PXE image being that should
  # be used for a given node on a testbed.
  #
  # - x,y = coordinate of the node to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] a String with the name of PXE image to use for the node matching
  #          the query
  #
  def getNodePXEImage(x, y, domain = "grid")
  qs = <<PXEIMAGE_QS
SELECT pxeimages.image_name
  FROM pxeimages
  LEFT JOIN nodes ON pxeimages.id = nodes.pxeimage_id
  LEFT JOIN locations ON nodes.location_id = locations.id
  LEFT JOIN testbeds ON locations.testbed_id = testbeds.id
WHERE testbeds.node_domain='#{domain}'
  AND locations.x=#{x}
  AND locations.y=#{y};
PXEIMAGE_QS

    imageName = nil
    runQuery(qs) { |name|
      imageName = name
    }
    return imageName
  end

  #
  # Query the Inventory database for all the nodes of a testbeds, which have an
  # inteface belonging to a given tag
  #
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] an Array with the coordinates of the nodes matching the query
  #
  def getNodeCoordinateRange(domain = "grid")
    qs = <<END_QS1
SELECT x_max, y_max, z_max
  FROM testbeds
WHERE node_domain = '#{domain}'
END_QS1

    result = Array.new
    runQuery(qs) { |x, y, z|
      result.push(x)
      result.push(y)
      result.push(z)
    }
    return result
  end

  #
  # Query the Inventory database for the ID of the motherboard at x/y/domain.
  # This is used for generating other more interesting queries.
  #
  # NOTE: Following code added by Winlab?, not sure if it is still used...
  #       if so please fix it so it follows the same pattern as previous getXXX
  #       (i.e. make use of the runQuery() routine)
  #
  # - x,y = coordinate of the node to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] the motherboard ID of the node matching the query
  #
  def getMotherboardID(x, y, domain = "grid")
    motherboardID = nil
    qs = "SELECT nodes.motherboard_id " \
         "FROM testbeds " \
           "LEFT JOIN locations ON testbeds.id = locations.testbed_id " \
           "LEFT JOIN nodes ON locations.id = nodes.location_id " \
	 "WHERE testbeds.node_domain = '#{domain}' " \
           "AND locations.x = #{x} " \
           "AND locations.y = #{y} "
    begin
      results=@my.query(qs)
      if results.each() { |mid|
          motherboardID = mid
        }
      end
    rescue MysqlError => e
      p "Inventory - Could not get Motherboard ID for T:#{domain} - X:#{x} - Y:#{y}"
      MObject.debug "Inventory - Could not get Motherboard ID for T:#{domain} - X:#{x} - Y:#{y}"
    end
    motherboardID
  end

  #
  # Query the Inventory database for the MAC address corresponding to all the
  # interfaces of a given node on a testbed, which have a certain type.
  #
  # NOTE: Following code added by Winlab?, not sure if it is still used...
  #       if so please fix it so it follows the same pattern as previous getXXX
  #       (i.e. make use of the runQuery() routine)
  #
  # - x,y = coordinate of the node to query
  # - type = type of the interface to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] the MAC addresses of the interfaces on the node matching the query
  #
  def getMacAddrByType(x, y, type = 1, domain = "grid")
    # This method should be considered deprecated because it exposes
    # device_id numbers to higher levels of abstraction.  device_id
    # numbers are not a "type", but rather a means of associating rows
    # in two tables in the database.  It is probably a better idea to
    # only expose PCI ID numbers.  See getMacAddrByOUI().
    p "Warning - getMacAddrByType() probably isn't what you want.  See getMacAddrByOUI()."
    MObject.warn "Inventory - getMacAddrByType() is deprecated."
    cards = []
    # First, find out the Motherboard ID of the requested node
    moid = getMotherboardID(x, y, domain)
    # Second, find out the MAC address of the interfaces with the required type on that Motherboard
    qs = "SELECT interfaces.mac interfaces.device_id " \
         "FROM interfaces " \
           "LEFT JOIN motherboards ON interfaces.motherboard_id = motherboards.id " \
	 "WHERE motherboards.id= #{moid} " \
	   "AND device_id = #{type} "
    begin
      results=@my.query(qs)
      if results.each() { |mac, did|
          p "  Got for ["+x.to_s+","+y.to_s+"] type="+type+" mac=["+mac+"]"
          cards |= mac
          MObject.debug " Inventory - T:#{domain} - X:#{x} - Y:#{y} - MAC:#{mac} - TYPE:#{did}"
        }
      end
    rescue MysqlError => e
      p "Inventory - Could not get MAC for T:#{domain} - X:#{x} - Y:#{y} - TYPE:#{type}"
      MObject.debug "Inventory - Could not get MAC for T:#{domain} - X:#{x} - Y:#{y} - TYPE:#{type}"
    end
    cards
  end

  #
  # Query the Inventory database for the MAC address corresponding to a
  # specific interface of a given node on a testbed.
  #
  # NOTE: Following code added by Winlab?, not sure if it is still used...
  #       if so please fix it so it follows the same pattern as previous getXXX
  #       (i.e. make use of the runQuery() routine)
  #
  # - x,y = coordinate of the node to query
  # - oui = OUI of the interface to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] the MAC address of the interface on the node matching the query
  #
  def getMacAddrByOUI(x, y, oui, domain = "grid")
    cards = []
    # XXX should start transaction here?
    moid = getMotherboardID(x, y, domain)
    qs = "SELECT interfaces.mac " \
         "FROM interfaces " \
           "LEFT JOIN motherboards ON interfaces.motherboard_id = motherboards.id " \
           "LEFT JOIN devices ON interfaces.device_id = devices.id " \
         "WHERE motherboards.id = #{moid} " \
           "AND devices.oui = #{oui} "
    begin
      results = @my.query(qs)
      if results.each() { | mac |
          cards |= mac
          MObject.debug " Inventory - T:#{domain} - X:#{x} - Y:#{y} - MAC:#{mac} - OUI:#{oui}"
        }
      end
    rescue MysqlError => e
      p "Inventory - Could not get MAC for T:#{domain} - X:#{x} - Y:#{y} - OUI:#{oui}"
      MObject.debug "Inventory - Could not get MAC for T:#{domain} - X:#{x} - Y:#{y} - OUI:#{oui}"
    end
    cards
  end

  def getAllPCIID(x, y, domain = "grid")
    result = Set.new
    motherboard_id = getMotherboardID(x, y, domain)
    querry_string = <<TeH_KWIRRY
SELECT devices.canonical_name, device_kinds.vendor, device_kinds.device
  FROM devices
  LEFT JOIN motherboards ON devices.motherboard_id = motherboards.id
  LEFT JOIN device_kinds ON devices.device_kind_id = device_kinds.id
  WHERE motherboards.id = #{motherboard_id}
TeH_KWIRRY
    begin
      @my.query(querry_string).each() { | cn, v, d | result.add([cn, v, d]) }
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in getAllPCIID; T:#{domain} - X:#{x} - Y:#{y}"
      p err_str
      MObject.debug err_str
    end
    result
  end

  #
  # Query the Inventory database for all the nodes having
  # an inteface with a given OUI
  #
  # NOTE: Following code added by Winlab?, not sure if it is still used...
  #       if so please fix it so it follows the same pattern as previous getXXX
  #       (i.e. make use of the runQuery() routine)
  #
  # - oui = oui to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] an Array with all the nodes matching the query
  #
  def getNodesWithOUIInterfaces(oui, domain = "grid")
    result = Array.new
    exists = Hash.new
    qs = <<END_QS
SELECT locations.x, locations.y
  FROM testbeds
  LEFT JOIN locations ON locations.testbed_id = testbeds.id
  LEFT JOIN nodes ON locations.id = nodes.location_id
  LEFT JOIN devices ON devices.motherboard_id = nodes.motherboard_id
  LEFT JOIN device_kinds ON device_kinds.id = devices.device_kind_id
  LEFT JOIN device_ouis ON device_ouis.device_kind_id = device_kinds.id
  WHERE device_ouis.oui = '#{oui}'
    AND testbeds.node_domain = '#{domain}'
  ORDER BY locations.x, locations.y
END_QS
    begin
      @my.query(qs).each() { | x, y |
          if (exists["#{x},#{y}"] == nil)
            exists["#{x},#{y}"] = "A"
           result.push([x,y])
          end
    }
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in getNodesWithOIUInterfaces; OUI:#{oui}, T:#{domain}"
      p err_str
      MObject.debug err_str
    end
    result
  end

  #
  # Query the Inventory database for all the aliases (tags) defined
  # in the tag table
  #
  # NOTE: Following code added by Winlab?, not sure if it is still used...
  #       if so please fix it so it follows the same pattern as previous getXXX
  #       (i.e. make use of the runQuery() routine)
  #
  # [Return] an Array with all the aliases from the Tag table
  #
  def getDeviceAliases()
    result = Array.new
    qs = <<END_QS1
SELECT DISTINCT tag
FROM `device_tags`
END_QS1
    begin
      @my.query(qs).each() { | t |
           result.push(t)
      }
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in getDeviceAliases"
      p err_str
      MObject.debug err_str
    end
    MObject.debug("Got result")
    result
  end

  #
  # Query the Inventory database for all the nodes having
  # an inteface belonging to a given tag
  #
  # NOTE: Following code added by Winlab?, not sure if it is still used...
  #       if so please fix it so it follows the same pattern as previous getXXX
  #       (i.e. make use of the runQuery() routine)
  #
  # - tag = tag to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] an Array with all the nodes matching the query
  #
  def getNodesWithTagInterfaces(tag, domain = "grid")
    result = Array.new
    qs = <<END_QS2
SELECT DISTINCT locations.x, locations.y
  FROM testbeds
  LEFT JOIN locations ON locations.testbed_id = testbeds.id
  LEFT JOIN nodes ON locations.id = nodes.location_id
  LEFT JOIN devices ON devices.motherboard_id = nodes.motherboard_id
  LEFT JOIN device_kinds ON device_kinds.id = devices.device_kind_id
  LEFT JOIN device_tags ON device_tags.device_kind_id = device_kinds.id
WHERE device_tags.tag = '#{tag}'
  AND testbeds.node_domain = '#{domain}'
ORDER BY locations.x, locations.y
END_QS2
    begin
      @my.query(qs).each() { | x, y |
           result.push([x,y])
    }
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in getNodesWithOIUInterfaces; OUI:#{oui}, T:#{domain}"
      p err_str
      MObject.debug err_str
    end
    result
  end

  #
  # Query the Inventory database for the names of all resources, which
  # are available for a given testbed.
  #
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] a Set with the names of all the resources
  #
  def getAllResources(domain = "grid")
  qs = <<ALLRESOURCES_QS
SELECT nodes.hrn
  FROM nodes 
  LEFT JOIN locations ON nodes.location_id = locations.id
  LEFT JOIN testbeds ON locations.testbed_id = testbeds.id
WHERE testbeds.node_domain='#{domain}';
ALLRESOURCES_QS

    resources = Set.new
    runQuery(qs) { |name|
      resources.add(name)
    }
    return resources
  end


  def getDHCPConfig(domain)
  qs = <<DHCP_QS
SELECT devices.mac, nodes.hostname, nodes.control_ip
  FROM devices
  LEFT JOIN nodes ON devices.motherboard_id = nodes.motherboard_id
  LEFT JOIN locations ON nodes.location_id = locations.id
  LEFT JOIN testbeds ON locations.testbed_id = testbeds.id
WHERE testbeds.node_domain='#{domain}';
DHCP_QS
 
    result = Array.new
    begin
      @my.query(qs).each() { | m, h, i |
           result.push([m,h,i])
    }
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in getDHCPconfig; domain #{domain}"
      p err_str
      MObject.debug err_str
    end
    result
  end
  
end

