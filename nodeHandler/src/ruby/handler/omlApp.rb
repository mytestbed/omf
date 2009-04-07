#
# Copyright (c) 2006-2008 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2008 WINLAB, Rutgers University, USA
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
# = omlApp.rb
#
# == Description
#
# This file defines the OmlApp, the OMLClientServlet, and the OMLServerServlet classes 
#
#
require 'webrick'
require 'stringio'
require 'date'
require 'external/mysql'
require 'util/mobject'

#
# This class represents an oml definition for a particular
# application configuration.
#
class OmlApp < MObject

  @@oml2ServerAddr = nil
  @@oml2ServerPort = nil

  @@mpCnt = 0
  @@dbName = nil
  @@initialized = false
  @@collectionServerStarted = false
  @@mpointsEl = nil

  #
  # Create a new OML definition/configuration for a given application
  #
  # - application = the Application for which to create the configuration
  # - name = Unique name of application, used for creating DB tables
  #
  # [Return] The url for a client to pick up it's OML configuration.
  #
  def OmlApp.create(application, name)

    if application.measurements.empty?
      return nil
    end

    if ! @@initialized
      @@initialized = true
      NodeHandlerServer.map("/omls", OMLServerServlet)
      NodeHandlerServer.map("/omlc", OMLClientServlet)
      NodeHandler::OML_EL.add_element('database-name').text = OmlApp.getDbName
      @@mpointsEl = NodeHandler::OML_EL.add_element('measurement-points')
    end

    id = "oml_#{name}"
    pel = @@mpointsEl

    application.measurements.each {|m|
      tableName = "#{name}_#{m.id}"
      el = pel.add_element("measurement-point",
      {'id' => (@@mpCnt += 1), 'name' => m.id, 'table' => tableName,
              'type' => m.filterMode, 'client' => id})
      properties = m.properties
      if properties.length > 0
        pe = el.add_element("properties")
        properties.each {|p|
          pe.add_element(p.to_xml)
        }
      end
      sorted = m.metrics.sort {|a, b| a[1].seqNo <=> b[1].seqNo}
      sorted.each {|arr|
        metric = arr[1]
        el.add_element(metric.to_xml)
      }
    }
    return "#{NodeHandlerServer.url()}/omlc?id=#{id}"
  end

  #
  # Return the name of the DB for this OML configuration
  # 
  # [Return] name of the DB 
  #
  def OmlApp.getDbName()
    if (@@dbName == nil)
      @@dbName = Experiment.ID
      #ts = DateTime.now.strftime("%F-%T")
      #name = "#{Experiment.name}_#{ts}"
      #@@dbName = name.split(%r{[-:/]}).join('_') # turn all non char into '_'
      #OmlApp.getDB.query("CREATE DATABASE #{@@dbName}")
    end
    return @@dbName
  end

  #
  # Start the OML (v2) Collection Server
  #
  def OmlApp.startCollectionServer()

    # Check if NH is running in 'slave' mode. If so, then this means this NH is 
    # being invoked directly on a specific node/resource which can be temporary 
    # disconnected from the Control Network. Thus, this NH has been invoked by
    # a 'master' Node Agent, which is then in charge of launching a Proxy OML
    # Collection Server. This NH then only retrieves the info for that Proxy 
    # Server from the 'master' NA.
    if NodeHandler.SLAVE_MODE
      # YES - then the OML server has already been launched by the Master NA
      # We just fetch its config setting from the 'slave' NH
      @@collectionServerStarted = true
      @@oml2ServerPort = NodeHandler.instance.omlProxyPort
      @@oml2ServerAddr = NodeHandler.instance.omlProxyAddr
      if ((@@oml2ServerPort == nil) || (@@oml2ServerAddr == nil))
        error("OmlApp", "Slave Mode - OML Proxy addr:port not set !")
      else
        info("OmlApp", "Slave Mode - OML Proxy at: #{@@oml2ServerAddr}:#{@@oml2ServerPort}")
      end
      return
    end

    # Check if an OMLv2 server for this experiment is not already running
    if @@collectionServerStarted
      # already running
      return
    end
    # Start a new OMLv2 server
    @@collectionServerStarted = true
    unless (omlService = OConfig.OML_SERVICE)
      return
    end
    url = "#{omlService}/start?id=#{Experiment.ID}&domain=#{OConfig.GRID_NAME}"
    #url = "#{OConfig.OML_SERVICE}/start?id=#{Experiment.ID}&domain=#{OConfig.GRID_NAME}"
    # Now we always use the same ID for the OML2 server, the new OML2 server will serve multiple experiment.
    url = "#{omlService}/start?id=#{OConfig.GRID_NAME}&domain=#{OConfig.GRID_NAME}"
    response = NodeHandler.service_call(url, "Can't start OML collection service")
    if response.kind_of?(Net::HTTPOK)
      # The server started correctly, retrieve its contact info from the HTTPresponse
      doc = REXML::Document.new(response.body)
      doc.root.elements.each() { |e|
        @@oml2ServerPort = e.attributes.get_attribute("port").value
        @@oml2ServerAddr = e.attributes.get_attribute("addr").value
      }
      @@collectionServerStarted = true
    else
      error "Failed to start OML server!"
    end
  end

  #
  # Start the OML (v1) Collection Server
  #
  # FIXME: What about if no application is using OML?
  #
  def OmlApp.startCollectionServerV1()

    if @@mpointsEl == nil
      # no measurements used
      return
    end

    if @@collectionServerStarted
      # already running
      return
    end

    @@collectionServerStarted = true

    ss = StringIO.new()
    ss.write("<?xml version='1.0'?>\n")
    ss.write("<experiment id=\"#{OmlApp.getDbName}\" domain=\"#{OConfig.GRID_NAME}\">\n")

    # WARNING: This may not work for multiple measurment points
    el = NodeHandler::OML_EL.elements["measurement-points"]
    #el.write(ss, 2) # Deprecated, replaced by next 2 lines
    f = REXML::Formatters::Pretty.new() 
    f.write(el, ss)
    ss.write("\n")

    ss.write("</experiment>\n")

    MObject.debug("OmlApp::startCollectionServer post on #{OConfig.OML_HOST}:#{OConfig.OML_PORT}\n",
    ss.string)
    if NodeHandler.JUST_PRINT
      puts "HTTP/POST #{OConfig.OML_HOST}:#{OConfig.OML_PORT}/oml/start\n#{ss.string}"
    else
      Net::HTTP.start(OConfig.OML_HOST, OConfig.OML_PORT) {|http|
        response = http.post('/oml/start', ss.string)
        if response.kind_of?(Net::HTTPOK)
          str = response.body
          MObject.debug("OmlApp::startCollectionServer response",str)

          doc = REXML::Document.new(str)
          mc = doc.root.elements['multicast-channel'].attributes

          attr = {'addr' => "#{mc['addr']}",
      'iface' => "#{mc['iface']}",
      'port' => "#{mc['port']}" }
          MObject.info("OML", "Started: ", attr.inspect)
          NodeHandler::OML_EL.add_element('multicast-channel', attr)
        else
          @@collectionServerStarted = false
          raise ServiceException.new(response,
        "OML collection server did not start properly. Check gridservices for details")
        end
      }
    end
    @@collectionServerStarted = true
  end

  #
  # Stop the OML collection server
  #
  def OmlApp.stopCollectionServer

    # Check if NH is running in 'slave' mode. 
    # If so then do nothing then the OML Proxy server is managed by the Master NA, do nothing
    if NodeHandler.SLAVE_MODE
      return
    end

    # Check if the server is really running
    if ! @@collectionServerStarted
      # not running
      return
    end
    # Yes, send a request to stop it to the GService
    unless (omlService = OConfig.OML_SERVICE)
      return
    end
    url = "#{omlService}/stop?id=#{OmlApp.getDbName}"
    NodeHandler.service_call(url, "Can't stop OML collection service")
  end

  #
  # Return the Address of the OML collection server
  #
  # [Return] an IP address 
  #
  def OmlApp.getServerAddr()
    return @@oml2ServerAddr
  end

  #
  # Return the Port of the OML collection server
  #
  # [Return] a Port number 
  #
  def OmlApp.getServerPort()
    return @@oml2ServerPort
  end
end

#
# This class defines the WEBrick servlet that will process GET request from OML clients
#
class OMLClientServlet < WEBrick::HTTPServlet::AbstractServlet

  #
  # Process GET request from client. 
  # Here we return back to the client the OML definition for this application
  #
  # - req = the full HTTP GET request
  # - res = the HTTP response to send back to the client
  #
  def do_GET(req, res)
    q = req.query
    id = q['id']
    if (id == nil)
      raise "Missing argument 'id'"
    end

    res['ContentType'] = "text/xml"
    ss = StringIO.new()
    ss.write("<?xml version='1.0'?>\n")
    ss.write("<experiment id=\"#{OmlApp.getDbName}\">\n")

    el = NodeHandler::OML_EL.elements['multicast-channel']
    #el.write(ss, 2) # Deprecated, replaced by next 2 lines
    f = REXML::Formatters::Pretty.new()
    f.write(el, ss)
    ss.write("\n")

    #    p "measurement-points[@id=\"#{id}\"]"
    ss.write("<measurement-points>\n")
    NodeHandler::OML_EL.elements.each("//measurement-point[@client=\"#{id}\"]") { |el|
      #el.write(ss, 2) # Deprecated, replaced by next line
      f.write(el, ss)
      ss.write("\n")
    }
    ss.write("</measurement-points>\n")

    ss.write("</experiment>\n")
    res.body = ss.string
  end
end

#
# This class defines the WEBrick servlet that will process GET request from clients
#
class OMLServerServlet < WEBrick::HTTPServlet::AbstractServlet

  #
  # Process GET request from client. 
  # Here we return back to the client the OML DB info for this application
  #
  # - req = the full HTTP GET request
  # - res = the HTTP response to send back to the client
  def do_GET(req, res)

    res['ContentType'] = "text/xml"
    ss = StringIO.new()
    ss.write("<?xml version='1.0'?>\n")
    ss.write("<experiment id=\"#{OmlApp.getDbName}\">\n")

    el = NodeHandler::OML_EL.elements['db']
    #el.write(ss, 2) # Deprecated, replaced by next 2 lines
    f = REXML::Formatters::Pretty.new()
    f.write(el, ss)
    ss.write("\n")
    el = NodeHandler::OML_EL.elements['multicast-channel']
    #el.write(ss, 2) # Deprecated, replaced by next line
    f.write(el, ss)
    ss.write("\n")

    # WARNING: This may not work for multiple measurment points
    el = NodeHandler::OML_EL.elements["measurement-points"]
    #el.write(ss, 2) # Deprecated, replaced by next line
    f.write(el, ss)
    ss.write("\n")

    ss.write("</experiment>\n")
    res.body = ss.string
  end
end

# Some Debug code...
#CREATE TABLE `foo2`.`senderport` (
#  `node_id` CHAR(32) NOT NULL,
#  `sequence_no` INTEGER UNSIGNED NOT NULL,
#  `timestamp` INTEGER UNSIGNED NOT NULL,
#  `pkt_sequ_no_sample_mean` FLOAT NOT NULL,
#  `pkt_timestamp_sample_mean` FLOAT NOT NULL,
#  `pkt_size_sample_mean` FLOAT NOT NULL
#)
