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
# = result.rb
#
# == Description
#
# This file defines the ResultService class.
#

require 'omf-aggmgr/ogs/legacyGridService'
require 'sqlite3'
#require 'omf-aggmgr/ogs_result/resultSQLite3'

#
# This class defines a Service to access the measurement results for a given 
# performed experiment. These results are stored in a Database. The only 
# database format currently supported is SQLite 3.
#
# IMPORTANT: this 'ResultService' needs to be colocated with the Oml2ServerService.
# In other words, the 'result' service needs to be running on the same server as the 
# 'oml2' service.
#
# For more details on how features of this Service are implemented below, please
# refer to the description of the AbstractService class
#
#
class ResultService < LegacyGridService

  # used to register/mount the service, the service's url will be based on it
  name 'result' 
  info 'Service to access and query experiment measurement databases'
  @@config = nil

  #
  # Return an interface to a given Experiment Database
  #
  # - experimentID = the ID of the Experiment
  #
  # [Return] an interface to the database holding the measurements for this Experiment
  #
  def self.getDatabase(experimentID)
    database = nil
    path = nil
    begin
      path = "#{@@config['database_path']}/#{experimentID}.sq3" 
      database = SQLite3::Database.new(path)
    rescue Exception => ex
      error "Result - Error opening Experiment Database --- PATH: '#{path}' --- '#{ex}'"
    end
    database
  end

  #
  # Create new XML element and add it to an existing XML tree
  #
  # - parent = the existing XML tree to add the new element to
  # - name = the name for the new XML element to add
  # - value =  the value for the new XML element to add
  #
  def self.addXMLElement(parent, name, value = nil)
     element = parent.add_element(name)
     if (value != nil)
       element.add_text(value)
     end
     element
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
      addXMLElement(root, "ERROR", "Error when accessing the Experiment Measurement Database")
    elsif (result == nil || result.empty?)
    addXMLElement(root, "ERROR", "#{msg}")
    else
      yield(root, result)
    end
    return root
  end

  #
  # Implement 'dumpDatabase' service using the 'service' method of AbstractService
  #
  s_info "Dump the complete database holding the measurement results for a given experiment"
  s_param :expID, 'ExperimentID', 'ID of the Experiment'
  service 'dumpDatabase' do |req, res|
    # Retrieve the request parameter
    id = getParam(req, 'expID')
    # Access and Query the experiment database
    dump = nil
    begin
      path = "#{@@config['database_path']}/#{id}.sq3" 
      cmd = "#{@@config['sqlite3_path']} #{path} .dump"
      dump =  `#{cmd}`
    rescue Exception => ex
      error "Result - Error dumping the experiment measurement database --- ID: #{id} --- '#{ex}'"
    end
    # The database dump should be returned as a pain text 
    # So the user can load the dump directly with SQLite3 without any reformatting
    result = "--\n-- Database Dump\n-- Experiment ID: #{id}\n--\n" + dump 
    setResponsePlainText(res, result)
  end
  
  #
  # Implement 'listTables' service using the 'service' method of AbstractService
  #
  s_info "Get the list of tables in given experiment measurement database"
  s_param :expID, 'ExperimentID', 'ID of the Experiment'
  service 'listTables' do |req, res|
    # Retrieve the request parameter
    id = getParam(req, 'expID')
    # Access and Query the experiment database
    result = nil
    begin
      path = "#{@@config['database_path']}/#{id}.sq3" 
      cmd = "#{@@config['sqlite3_path']} #{path} .tables"
      result =  `#{cmd}`
    rescue Exception => ex
      error "Result - Error retrieving table list for the experiment measurement database --- ID: #{id} --- '#{ex}'"
    end
    # Build and Set the XML response
    msgEmpty = "No table info from this experiment measurement database --- ID: #{id} --- #{ex} "
    replyXML = buildXMLReply("DATABASE", result, msgEmpty) { |root,list|
      list.split(" ").each { |table|
        addXMLElement(root, "TABLE", "#{table}")
      }
    }
    replyXML.add_attribute("ExperimentID", "#{id}")
    setResponse(res, replyXML)
  end
  
  #
  # Implement 'listTables' service using the 'service' method of AbstractService
  #
  s_info "Get the Schema of a given experiment measurement database"
  s_param :expID, 'ExperimentID', 'ID of the Experiment'
  service 'getSchema' do |req, res|
    # Retrieve the request parameter
    id = getParam(req, 'expID')
    # Access and Query the experiment database
    result = nil
    begin
      path = "#{@@config['database_path']}/#{id}.sq3" 
      cmd = "#{@@config['sqlite3_path']} #{path} .schema"
      result =  `#{cmd}`
    rescue Exception => ex
      error "Result - Error retrieving Schema for the experiment measurement database --- ID: #{id} --- '#{ex}'"
    end
    # Build and Set the XML response
    msgEmpty = "No Schema info from this experiment measurement database --- ID: #{id} --- #{ex} "
    replyXML = buildXMLReply("DATABASE", result, msgEmpty) { |root,schema|
      addXMLElement(root, "SCHEMA", "#{schema}")
    }
    replyXML.add_attribute("ExperimentID", "#{id}")
    setResponse(res, replyXML)
  end
  
  #
  # Implement 'queryDatabase' service using the 'service' method of AbstractService
  #
  s_info "Get the Schema of a given experiment measurement database"
  s_param :expID, 'ExperimentID', 'ID of the Experiment'
  s_param :query, 'SQLquery', 'An SQLite query to run against the database'
  s_param :format, 'raw | xml | json | cvs | merged', 'Format to return result in.', "xml"
  service 'queryDatabase' do |req, res|
    # Retrieve the request parameter
    id = getParam(req, 'expID')
    sqlQuery = getParam(req, 'query')
    format = getParamDef(req, 'format', 'xml')
    
    # Access and Query the experiment database
    result = nil
    begin
      database = getDatabase(id)
      database.type_translation = true if format == "json"
      resultColumns, *resultRows = database.execute2(sqlQuery)
      database.close()
    rescue Exception => ex
      error "Result - Error executing Query for the experiment measurement database --- ID: #{id} --- QUERY: '#{sqlQuery}' --- '#{ex}'"
    end
    # Build and Set the XML response
    msgEmpty = "No Result from Query against this experiment measurement database --- ID: #{id} --- QUERY: #{sqlQuery} --- #{ex} "
    case format
      when 'raw'
        reply = formatResultRAW(id, sqlQuery, resultColumns, resultRows, msgEmpty)
        res.body = reply
        res['Content-Type'] = "text/plain"
      when 'xml'
        reply = formatResultXML(id, sqlQuery, resultColumns, resultRows, msgEmpty)
        setResponse(res, reply)
      when 'json'
        reply = formatResultJSON(id, sqlQuery, resultColumns, resultRows, msgEmpty)
        res.body = reply
        res['Content-Type'] = "text/json"
      when 'csv'
        reply = formatResultCSV(id, sqlQuery, resultColumns, resultRows, msgEmpty)
        res.body = reply
        res['Content-Type'] = "text/csv"
      when 'merged'
        reply = formatResultCSVMerged(id, sqlQuery, resultColumns, resultRows, msgEmpty)
        res.body = reply
        res['Content-Type'] = "text/csv"
      else
        error "Unknown reply format '#{format}'"
    end
  end
  
  def self.formatResultRAW(id, sqlQuery, resultColumns, resultRows, msgEmpty)
    reply = ""
    lineNum = 1
    resultRows.each { |row|
      reply = reply + "#{lineNum} #{row.join(" ")}\n"
      lineNum = lineNum + 1
    }
    reply
  end
  
  def self.formatResultXML(id, sqlQuery, resultColumns, resultRows, msgEmpty)
    # XMLRoot is 'DATABASE'
    replyXML = buildXMLReply("DATABASE", resultRows, msgEmpty) { |root,rows|
      # Add Element 'DATABASE - QUERY'     
      addXMLElement(root, "QUERY", "#{sqlQuery}")
      # Add Element 'DATABASE - RESULT'     
      element = addXMLElement(root, "RESULT")
      # Add Element 'DATABASE - RESULT - FIELDS'     
      line = resultColumns.join(" ")
      addXMLElement(element, 'FIELDS', "#{line}")
      # Add Element 'DATABASE - RESULT - ROW' for each row in the result    
      rows.each { |aRow|
        line = aRow.join(" ")
        addXMLElement(element, 'ROW', "#{line}")
      }
    }
    replyXML.add_attribute("ExperimentID", "#{id}")
    replyXML    
  end
  
  require 'stringio'
  def self.formatResultJSON(id, sqlQuery, resultColumns, resultRows, msgEmpty)
    reply = %{
{"oml_res" : {
  "expID" : "#{id}",
  "query" : #{sqlQuery.inspect},
  "columns" : #{(resultColumns || []).inspect},
  "rows" : #{(resultRows || []).inspect}
}}
}
    reply
  end

  def self.formatResultCSV(id, sqlQuery, resultColumns, resultRows, msgEmpty)
    reply = StringIO.new
    (resultRows || []).each do |cols|
      reply << cols.join(';') << "\n"
    end
    reply.string
  end

  # This method treats the result in the following manner:
  #  * It expects three colums: oml_ts_server (sorted by), oml_sender_id, anyValue
  #  * It groups the results by oml_sender_id and creates a vector <ts, value1, value2, ..
  #
  def self.formatResultCSVMerged(id, sqlQuery, resultColumns, resultRows, msgEmpty)
    reply = StringIO.new
    h = {}
    names = []
    names_h = {}
    start_ts = nil
    prev_ts = 0
    (resultRows || []).each do |cols|
      ts = (cols.shift || 0).to_i
      start_ts ||= ts
      node = cols.shift
      value = cols.shift
      unless names_h.key?(node)
        # keep track of node names
        names << node
        names_h[node] = true
      end
      #reply << "SINGLE: #{node}:#{h.inspect}"      
      if h.key?(node)
        # got another value for +node+, output graph row
        va = names.collect do |n| h[n] end
        #reply << "EMPTY <#{va.inspect}><#{va.join(';')}:#{h.inspect}"
        unless (vas = va.join(';')).empty?
          
          if (ts_d = start_ts - prev_ts) > 0
            i = 0
            while ts_d < 1.0 
              i += 1; ts_d *= 10
            end
            ts_s = sprintf("%.#{i}f", start_ts)
          else
            ts_s = 0
          end
          reply << ts_s << ';' << vas << "\n"
        end
        h = {}
        prev_ts = start_ts
        start_ts = nil
      end
      h[node] = value
    end
    # prepand empty record of size names
    (';' * names.size) + "\n" + reply.string
  end
  
  
  
  #
  # Configure the service through a hash of options
  #
  # - config = the Hash holding the config parameters for this service
  #
  def self.configure(config)
    @@config = config
    error("Missing configuration 'sqlite3_path'") if @@config['sqlite3_path'] == nil
    error("Missing configuration 'database_path'") if @@config['database_path'] == nil
  end
  
  # Overide the 'mont' call when installing the service to install the 
  # flash security handler.
  #
  def self.mount(server, prefix = "/#{self.serviceName}")
    #warn "MOUNT: #{server.inspect}"
    server.mount_proc('/crossdomain.xml') do |req, resp|
      resp.body = %{
<cross-domain-policy>
  <allow-access-from domain="*"/>
</cross-domain-policy>
}
      resp['content-type'] = 'text/xml'
    end
    super
  end
  
end
