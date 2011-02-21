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
  # - user = user to access this database
  # - password = password to access this database
  # - database = name of the database (default = inventory)
  #
  def initialize(host, user, password, database = "inventory")
    @connected = false
    @my    = nil
    @host  = host
    @user  = user
    @pw    = password
    @db    = database
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
      @connected = true
    rescue MysqlError => e
      debug "SQL error message: #{e.error}."
    end
  end

  #
  # Close a previously opened connection to the MySQL server
  #
  def close()
    @connected = false
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
    raise "Trying to run a query when not connected to inventory DB" if not @connected
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
WHERE testbeds.name='#{domain}'
  AND nodes.hrn='#{hrn}';
CONTROL_QS

    addr = nil
    runQuery(qs) { |ip|
      addr = ip
    }
    return addr
  end
  
  #
  # Query the Inventory database for the CMC IP address of a specific node
  # on a testbed.
  #
  # - hrn = HRN of the node to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] the CMC IP address of the node matching the query
  #
  def getCmcIP(hrn, domain = "grid")
    qs = <<CONTROL_QS
SELECT nodes.cmc_ip
  FROM nodes
  LEFT JOIN locations ON nodes.location_id = locations.id
  LEFT JOIN testbeds ON locations.testbed_id = testbeds.id
WHERE testbeds.name='#{domain}'
  AND nodes.hrn='#{hrn}';
CONTROL_QS

    addr = nil
    runQuery(qs) { |ip|
      addr = ip
    }
    return addr
  end  

  #
  # Query the Inventory database for the HRN of a specific node
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
WHERE testbeds.name='#{domain}'
  AND nodes.hostname='#{hostname}';
HRN_QS

      addr = nil
      runQuery(qs) { |i|
        addr = i
      }
      return addr
    end

  #
  # Query the Inventory database for the default disk of a specific node
  # on a testbed.
  #
  # - hrn = hrn of the node to query
  # - domain = name of the testbed to query (default=grid)
  #
  # [Return] the default disk of the node matching the query
  #
  def getDefaultDisk(hrn, domain = "grid")
    qs = <<DD_QS
SELECT nodes.disk
  FROM nodes
  LEFT JOIN locations ON nodes.location_id = locations.id
  LEFT JOIN testbeds ON locations.testbed_id = testbeds.id
WHERE testbeds.name='#{domain}'
  AND nodes.hrn='#{hrn}';
DD_QS

      disk = nil
      runQuery(qs) { |i|
        disk = i
      }
      return disk
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
  def getNodePXEImage(hrn, domain = "grid")
  qs = <<PXEIMAGE_QS
SELECT pxeimages.image_name
  FROM pxeimages
  LEFT JOIN nodes ON pxeimages.id = nodes.pxeimage_id
  LEFT JOIN locations ON nodes.location_id = locations.id
  LEFT JOIN testbeds ON locations.testbed_id = testbeds.id
WHERE testbeds.name='#{domain}'
  AND nodes.hrn='#{hrn}'
PXEIMAGE_QS

    imageName = nil
    runQuery(qs) { |name|
      imageName = name
    }
    return imageName
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
WHERE testbeds.name='#{domain}';
ALLRESOURCES_QS

    resources = Set.new
    runQuery(qs) { |name|
      resources.add(name)
    }
    return resources
  end

  def getAllTestbeds
  qs = <<ALLTESTBEDS_QS
SELECT name FROM testbeds;
ALLTESTBEDS_QS

    result = Array.new
    begin
      @my.query(qs).each() { | n |
           result << n
    }
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in getAllTestbeds"
      p err_str
      MObject.debug err_str
    end
    result
  end

  def getAllNodes
  qs = <<ALLNODES_QS
SELECT hostname,hrn,control_mac,control_ip,x,y,z,disk,testbeds.name
FROM nodes
LEFT JOIN locations ON nodes.location_id = locations.id
LEFT JOIN testbeds ON locations.testbed_id = testbeds.id
;
ALLNODES_QS

    result = Array.new
    begin
      @my.query(qs).each() { | hostname,hrn,control_mac,control_ip,x,y,z,disk,tbname |
           result << {'name' => "#{hostname}", 'hrn' => "#{hrn}", 'control_mac' => "#{control_mac}",
             'control_ip' => "#{control_ip}", 'x' => "#{x}", 'y' => "#{y}", 'z' => "#{z}", 'disk' => "#{disk}",
             'testbed' => "#{tbname}"}
    }
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in getAllTestbeds"
      p err_str
      MObject.debug err_str
    end
    result
  end

  def addTestbed(testbed)
    qs = "INSERT INTO testbeds (name) VALUES ('#{testbed}');"
    begin
      @my.query(qs)
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in rmTestbed: '#{qs}'"
      p err_str
      MObject.debug err_str
    end
    return @my.affected_rows > 0
  end
  
  def editTestbed(testbed, name)
    qs = "UPDATE testbeds SET name = '#{name}' WHERE name = '#{testbed}';"
    begin
      @my.query(qs)
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in editTestbed: '#{qs}'"
      p err_str
      MObject.debug err_str
    end
    return @my.affected_rows > 0
  end
  
  def rmTestbed(testbed)
    qs = "DELETE FROM testbeds WHERE name = '#{testbed}';"
    begin
      @my.query(qs)
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in rmTestbed: '#{qs}'"
      p err_str
      MObject.debug err_str
    end
    return @my.affected_rows > 0
  end
  
  def addNode(node)
    qs = "INSERT INTO nodes (#{node.keys.join(',')}) VALUES ('#{node.values.join('\',\'')}');"
    MObject.debug(qs)
    return true
    begin
      @my.query(qs)
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in rmTestbed: '#{qs}'"
      p err_str
      MObject.debug err_str
    end
    return @my.affected_rows > 0
  end
  
  def rmNode(node,testbed)
    qs = "DELETE FROM nodes WHERE name = '#{node}';"
    begin
      @my.query(qs)
    rescue MysqlError => e
      err_str = "Inventory - Could not execute query in rmNode: '#{qs}'"
      p err_str
      MObject.debug err_str
    end
    return @my.affected_rows > 0
  end

end

