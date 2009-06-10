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
# = omlserverd.rb
#
# == Description
#
# This file defines the OmlServerDaemon class.
#
# NOTE: OmlServerDaemon is deprecated, please use Oml2ServerDaemon instead
# 
#

require 'omf-aggmgr/ogs/abstractDaemon'
require 'mysql'

#
# NOTE: OmlServerDaemon is deprecated, please use Oml2ServerDaemon instead
#       Since this class is deprecated, we did not include RDoc comments in its
#       code below. 
# 
class OmlServerDaemon < AbstractDaemon

  # Multicast address to use for servicing images
  DEF_ADDRESS = "224.0.0.6"

  DEF_SERVER_BIN = '/usr/bin/oml_collection_server'
  DEF_SERVER_DEBUG_LEVEL = 5

  # Mapping between OML data types and SQL types.
  # Fix the duplication of xsd: and plain types.
  XSD2SQL = {
    "xsd:float" => "FLOAT NOT NULL",
    "xsd:int" => "INTEGER NOT NULL",
#    "xsd:long" => "LONG NOT NULL",
    "xsd:long" => "INTEGER NOT NULL",
    "xsd:short" => "INTEGER NOT NULL",
    "xsd:bool" => "DO NOT KNOW",
    "xsd:string" => "CHAR(32) NOT NULL",
    "float" => "FLOAT NOT NULL",
    "int" => "INTEGER NOT NULL",
#    "long" => "LONG NOT NULL",
    "long" => "INTEGER NOT NULL",
    "short" => "INTEGER NOT NULL",
    "bool" => "DO NOT KNOW",
    "string" => "CHAR(32) NOT NULL"
  }

  def self.daemon_name(req)
    name = getDaemonParam(req, 'id')
  end

  attr_reader :daemon_id, :addr, :port, :iface, :logFile, :running

  def initialize(req)
    @dbHandle = nil
    @dbConfig = Hash.new
    @root = self.class.getDaemonParam(req, 'config_root')
    @daemon_id = self.class.getDaemonParam(req, 'id')
    super(req)
  end

  # Override this with daemon specific defaults
  def configDefaults(config)
    if ((@dbConfig = config['database']) == nil)
      raise "Missing 'database' configuration in OML collection service"
    end
    if (@dbConfig['host'].nil? || @dbConfig['user'].nil? || @dbConfig['password'].nil?)
      raise "Missing 'host', or 'user', or 'password' configuration " + \
        "in the 'database' section of OML collection service"
    end
    config['serverAddress'] ||= DEF_ADDRESS
    config['serverBin'] ||= DEF_SERVER_BIN
    config['serverDebugLevel'] ||= DEF_SERVER_DEBUG_LEVEL

    raise "Missing 'localIf' definition" if config['localIf'].nil?
    raise "File '#{config['serverBin']}' not executable" if !File.executable?(config['serverBin'])
  end

  # Return the command string for starting the daemon
  def getCommand()
    @serverCfgFile = createServerConfig(@config)
    createDB(@root)
    @dbHandle.close()

    @logFile = "/tmp/#{@daemon_id}.log"
    dbDir = "/tmp/#{@daemon_id}"
    cmd = "env LD_LIBRARY_PATH=#{@config['berkeleyDB']} #{@config['serverBin']} -l #{@logFile} -d #{@config['serverDebugLevel']} -b #{dbDir} #{@serverCfgFile}"    
    debug("Exec '#{cmd}'")
    cmd
  end


  #
  # Create a config file for the collection server and
  # return the name of the file
  #
  def createServerConfig(config)

    @addr = config['serverAddress']
    @iface = config['localIf']

    @root.add_element("multicast-channel",
    {'port' => @port, 'addr' => @addr, 'iface' => @iface})
    @root.add_element("db",
    {'user' => @dbConfig['user'], 'id' => @daemon_id,
     'host' => @dbConfig['host'], 'password' => @dbConfig['password']})

    cfgFile = "/tmp/#{@daemon_id}.xml"
    f = File.open(cfgFile, "w")
    formatter = REXML::Formatters::Default.new
    formatter.write(@root,f)
    f.close
    info("Wrote config to #{cfgFile}")
    cfgFile
  end


  def createDB(root)
    @dbHandle = dbHandle()
    info("Create database #{@daemon_id}")
    sql = "DROP DATABASE IF EXISTS #{@daemon_id};"
    debug(sql)
    @dbHandle.query(sql)

#    sql = "DROP DATABASE #{@daemon_id};"
    sql = "CREATE DATABASE #{@daemon_id};"
    debug(sql)
    @dbHandle.query(sql)

    cnt = 1
    root.elements.each("//measurement-point") { |mp|
      tableName = mp.attributes['table']
      if (tableName == nil)
        tableName = mp.attributes['name'] + cnt.to_s
        cnt += 1
      end
      sql = "CREATE TABLE #{@daemon_id}.#{tableName} ("
      sql += "node_id VARCHAR(32), "
      sql += "sequence_no INTEGER NOT NULL, "
      sql += "timestamp INTEGER NOT NULL, "
      spacer = ""
      mp.elements.each("metric") { |m|
        sql += spacer
        refid = m.attributes['refid']
        if (refid == nil)
          raise "Missing attribute 'refid' in metric"
        end
        filters = m.elements.to_a("filter")
        if filters.length == 0
          type = m.attributes['type']
          raise "Missing type in #{m.to_s}" if type == nil
          sql += "#{refid} #{XSD2SQL[type]}"
        else
          spacer2 = ""
          filters.each {|f|
            f_refid = f.attributes['refid']
            type = f.attributes['returnType']
            raise "Missing type in filter #{f.to_s} in #{m.to_s}" if type == nil
            sql += "#{spacer2}#{refid}_#{f_refid} #{XSD2SQL[type]}"
            spacer2 = ", "
          }
        end
        spacer = ", "
      }
      sql += "); "
      debug(sql)
      @dbHandle.query(sql)
    }
  end

  def dbHandle()
    host = @dbConfig['host']
    user = @dbConfig['user']
    pw = @dbConfig['password']
    begin 
      @dbHandle = Mysql.connect(host, user, pw)
    rescue Exception => ex
      raise "While connecting to database '#{user}@#{host}': #{ex}"
    end
    @dbHandle
  end

  # Return the settings of the collection server
  # relevant to a client.
  #
  def serverDescription(parentElement)
    attr = Hash.new
    attr['id'] = @daemon_id
    attr['logfile'] = @logFile
    attr['timeLeft'] = @untilTimeout
    attr['addr'] = @addr
    attr['port'] = @port
    attr['iface'] = @iface
    parentElement.add_element('daemon', attr)
    parentElement
  end

end
