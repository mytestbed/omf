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
# = gridService.rb
#
# == Description
#
# This file defines GridService and HTTPResponse classes.
#

require 'omf-aggmgr/ogs/abstractService'

#
# This class defines the GridService class a sub-class of AbstractService.
# Compared to an AbstractService, a GridService object provides access to 
# configuration parameters for a particular testbed, and also provides access to
# testbed and node related parameters from the HTTP request sent to the Service.
#
class GridService < AbstractService

  #
  # Return the set of configuration parameters for a given domain.
  #
  # What is returned is either the parameters within the section
  # /testbed/'domain' or the config file, or if not found the ones within the
  # section /testbed/default. If both are not found, an exception is raised.
  #
  # - req =  the HTTP request sent to this Service, with the 'domain' field set
  # - serviceConfig = Hash with all the parsed entries from the config file
  #
  # [Return] a Hash with the configuration parameters for a given domain
  # 
  def self.getTestbedConfig(req, serviceConfig)
    domain = getParam(req, 'domain')
    if ((dc = serviceConfig['testbed']) == nil)
      raise HTTPStatus::ServerError, "Missing 'testbed' configuration"
    end
    config = dc[domain] || dc['default']
    if (config == nil)
      raise HTTPStatus::ServerError, "Missing 'testbed' config for '#{domain}' or 'default'"
    end
    config
  end

  #
  # Configure the HTTP Response ('res') from this Service so it returns an OK 
  # response
  #
  # - res = the HTTP Response message to update
  #
  def self.responseOK(res)
    res['Content-Type'] = "text"
    res.body = "OK"
  end

  #
  # Make this Service to return 'resXml' as 'text/xml'
  #
  # - res = the HTTP Response message to update
  # - resXML =  the resXML to turn into text/XML
  #
  def self.setResponse(res, resXml)
    s = StringIO.new
    resXml.write(s)
    res.body = s.string
    res['Content-Type'] = "text/xml"
  end

  #
  # Parse a given parameter inside a HTTP request (sent to this Service) into
  # a Node Set declaration, which is an array of Node Sets. If this parameter is 
  # not present in the request, then parse the 'default' argument instead.
  #
  # - req =  the HTTP request sent to this Service, with the 'name' field set
  # - name = name of the parameter to parse inside the HTTP request
  # - default = a default parameter if 'name' is not present in the request
  #
  # [Return] a Node Set declaration (array of Node Sets), or nil, or []
  #
  def self.getNodeSetParamDef(req, name, default)
    str = req.query[name] || default
    if (str == nil)
      return nil
    elsif (str == "[]")
      res = []
      return res
    end

    res = nil
    begin
      Thread.new() {
        $SAFE = 4
        res = eval(str)
      }.join
    rescue Exception => ex
      raise HTTPStatus::BadRequest, "Error while parsing '#{str}'\n\t#{ex}"
    end
    if (! res.kind_of?(Array))
      raise HTTPStatus::BadRequest, "Illegal node set declaration '#{str}'"
    end
    if (! res[0].kind_of?(Array))
      # seems to be a single set declaration
      res = [res]
    end
    # validate
    res.each { |ns|
      if (! (ns.kind_of?(Array) \
             &&  ns.length == 2 \
             && (ns[0].kind_of?(Integer) || ns[0].kind_of?(Range)) \
             && (ns[1].kind_of?(Integer) || ns[1].kind_of?(Range))))
        raise HTTPStatus::BadRequest, "Illegal node set declaration '#{ns}'"
      end
    }
  end

  #
  # Parse a given parameter inside a HTTP request (sent to this Service) into
  # a Node Set declaration, which is an array of Node Sets. If this parameter is 
  # not present in the request, then raise an error.
  #
  # - req =  the HTTP request sent to this Service, with the 'name' field set
  # - name = name of the parameter to parse inside the HTTP request
  #
  # [Return] a Node Set declaration (array of Node Sets)
  #
  def self.getNodeSetParam(req, name)
    res = getNodeSetParamDef(req, name, nil)
    if (res == nil)
      raise HTTPStatus::BadRequest, "Missing parameter '#{name}'"
    end
    res
  end
  
  #
  # Parse the 'x' and 'y' parameters inside a HTTP request (sent to this 
  # Service) into x,y integers. Raise an error if 'x' and 'y' parameters are not
  # present in the request.
  #
  # - req =  the HTTP request sent to this Service, with the 'x' & 'y' field set
  #
  # [Return] a integer couple [x,y]
  #
  def self.getCoords(req)
    q = req.query
    x = q['x']
    y = q['y']
    # Do we have everything?
    if (x == nil || y == nil)
      raise HTTPStatus::BadRequest, "Missing argument 'x', or 'y'"
    end
    return [x.to_i, y.to_i]
  end

  #
  # Call a block of command on this Service, after a given timer as expired
  # for this Service. This given timer can be reset by multiple calls to this 
  # function with the same 'key'
  #
  # - key =  the key associated with the Timer
  # - timeout = the timeout duration in sec
  # - &block =  the block of commands to execute after 'timeout'
  #
  def self.timeout(key, timeout, &block)
    @@timeoutMutex.synchronize {
    # should put inside monitor to make thread safe
    @@timeouts[key] = [Time.now + timeout, key, block]
    if (@@timeoutThreads != nil)
      @@timeoutThreads.wakeup
    else
      @@timeoutThreads = Thread.new() {
        while (! @@timeouts.empty?)
          tasks = @@timeouts.values.sort { |a, b| a[0] <=> b[0] }
          now = Time.now
          nextTask = tasks.detect { |t|
            if (t[0] <= now)
              debug "Timing out #{t[1]}"
              t[2].call
              @@timeouts.delete(t[1])
              false
            else
              # return the first job in the future
              true
            end
          }
          if (nextTask != nil)
            delta = nextTask[0] - now
            debug "Check for time out in '#{delta}'"
            sleep delta
          end
        end
        @@timeoutThreads = nil
      }
    end
    }
  end

  #
  # Cancel a previously set Timer 
  #
  # - key = the key associated with the previously set Timer to cancel
  #
  def self.cancelTimeout(key)
    @@timeouts.delete(key)
  end

  #
  # Assert if a given value is within a given range. Raise an error message
  # otherwise
  #
  # - value = the value to assert
  # - range = the range to test the value with
  # - errMessage = the text error message to raise if 'value' is not in 'range'
  #
  # [Return] true if 'value' is within 'range'
  #
  def self.assertRange(value, range, errMessage)
    range === value || raise(HTTPStatus::BadRequest, errMessage)
  end
  
  #
  # Return the Control IP address of a specific node on a given testbed. This 
  # method makes use of the Inventory GridService
  #
  # - url = URL to the Inventory GridService
  # - x,y = coordinate of the node to query
  # - domain = name of the testbed to query
  #
  def self.getControlIP(url, x, y, domain)
    queryURL = "#{url}/getControlIP?x=#{x}&y=#{y}&domain=#{domain}"
    debug "GridService - QueryURL: #{queryURL}"
    response = nil
    response = Net::HTTP.get_response(URI.parse(queryURL))
    if (! response.kind_of? Net::HTTPSuccess)
          error "GridService - No Control IP found for x: #{x} y: #{y} - Bad Response from Inventory"
          error "GridService - QueryURL: #{queryURL}"
          raise Exception.new()
    end
    if (response == nil)
      error "GridService - No Control IP found for x: #{x} y: #{y} - Response from Inventory is NIL"
      error "GridService - QueryURL: #{queryURL}"
      raise Exception.new()
    end 
    doc = REXML::Document.new(response.body)
    # Parse the Reply to retrieve the control IP address
    ip = nil
    doc.root.elements.each("/CONTROL_IP") { |v|
      ip = v.get_text.value
    }
    # If no IP found in the reply... raise an error
    if (ip == nil)
      doc.root.elements.each('/ERROR') { |e|
        error "GridService - No Control IP found for x: #{x} y: #{y} - val: #{e.get_text.value}"
      }
    end
    return ip
  end

  #
  # Return an Array of node coordinates for a a given tesbed [(1..xMax),(1..yMax)]
  #
  # - url = URL to the Inventory GridService
  # - domain = the name of the testbed to considere
  #
  # [Return] an Array of node coordinates [x,y]
  #
  def self.listAllNodes(url, domain)
    allNodes = []
    xMax, yMax = getXYMax(url, domain)
    (1..yMax).each {|y|
      (1..xMax).each {|x|
        allNodes << [x,y]
      }
    }
    allNodes
  end

  #
  # Return the XMax and YMax values for all the nodes on a given testbed. This 
  # method makes use of the Inventory GridService
  #
  # - url = URL to the Inventory GridService
  # - domain = name of the testbed to query
  #
  #
  def self.getXYMax(url, domain)
    queryURL = "#{url}/getConfig?domain=#{domain}"
    debug "QueryURL: #{queryURL}"
    response = nil
    response = Net::HTTP.get_response(URI.parse(queryURL))
    if (! response.kind_of? Net::HTTPSuccess)
          error "No XMax/YMax info found for t: #{domain} - Bad Response from Inventory"
          error "QueryURL: #{queryURL}"
          raise Exception.new()
    end
    if (response == nil)
      error "No XMax/YMax info found for t: #{domain} - Response from Inventory is NIL"
      error "QueryURL: #{queryURL}"
      raise Exception.new()
    end
    doc = REXML::Document.new(response.body)
    # Parse the Reply to retrieve the PXE Image name
    xmax = nil
    ymax = nil
    doc.root.elements.each("/CONFIG/x_max") { |v|
      xmax = v.get_text.value
    }
    doc.root.elements.each("/CONFIG/y_max") { |v|
      ymax = v.get_text.value
    }
    # If no name found in the reply... raise an error
    if (xmax == nil || ymax == nil)
      doc.root.elements.each('/ERROR') { |e|
        error "No XMax/YMax info found for t: #{domain} - val: #{e.get_text.value}"
      }
    end
    return xmax.to_i, ymax.to_i
  end

end # class

#
# Return the error messages as simple text in the response body
#
class HTTPResponse
  def set_error(ex, backtrace=false)
    case ex
    when HTTPStatus::Status
      @keep_alive = false if HTTPStatus::error?(ex.code)
      self.status = ex.code
      @body = ex.message
    else
      @keep_alive = false
      self.status = HTTPStatus::RC_INTERNAL_SERVER_ERROR
      @body = "internal error"
    end
    @header['content-type'] = "text"
  end
end
