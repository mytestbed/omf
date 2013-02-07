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


class ServiceError < Exception; end
class BadRequest < ServiceError; end

#
# This class defines the GridService class a sub-class of AbstractService.
# Compared to an AbstractService, a GridService object provides access to
# configuration parameters for a particular testbed, and also provides access to
# testbed and node related parameters from the HTTP request sent to the Service.
#
class GridService < AbstractService
  
  # generate an XML fragment "<OK>msg</OK>" which is returned on success
  def self.return_ok(msg = nil)
    r = REXML::Element.new("OK")
    r.text = "#{msg}" if !msg.nil?
    r
  end
  
  # generate an XML fragment "<ERROR>msg</ERROR>" which is returned on error
  def self.return_error(msg = nil)
    r = REXML::Element.new("ERROR")
    r.text = "#{msg}" if !msg.nil?
    r
  end
  #
  # Return the set of configuration parameters for a given domain.
  #
  # What is returned is either the parameters within the section
  # /testbed/'domain' or the config file, or if not found the ones within the
  # section /testbed/default. If both are not found, an exception is raised.
  #
  # - domain = The domain to query.
  # - serviceConfig = Hash with all the parsed entries from the config file for this service
  #
  # [Return] a Hash with the configuration parameters for a given domain
  #
  def self.getTestbedConfig(domain, serviceConfig)
    if ((dc = serviceConfig['testbed']) == nil)
      raise ServiceError, "Missing 'testbed' configuration"
    end
    config = dc[domain] || dc['default']
    if (config == nil)
      raise ServiceError, "Missing 'testbed' config for '#{domain}' or 'default'"
    end
    config
  end

  #
  # Return the Control IP address of a specific node on a given testbed. This
  # method makes use of the Inventory GridService
  #
  # - name = HRN of the node to query
  # - domain = name of the testbed to query
  #
  def self.getControlIP(hrn, domain)
    doc = nil
    begin
      doc = OMF::Services.inventory.getControlIP(hrn, domain)
    rescue Exception => e
      MObject.error "Error trying to get control IP address for resource '#{hrn}' in domain '#{domain}': #{e}"
      raise ServiceError, e.message
    end

    # Parse the Reply to retrieve the control IP address
    ip = nil
    doc.root.elements.each("/CONTROL_IP") { |v|
      ip = v.get_text.value if !v.get_text.nil?
    }
    # If no IP address found in the reply... raise an error
    if (ip.nil?)
      doc.root.elements.each('/CONTROL_IP/ERROR') { |e|
        raise ServiceError, "GridService - No CMC IP address found for '#{hrn}' - Error: #{e.get_text.value}"
      }
    end
    return ip
  end

  #
  # Return the CMC IP address of a specific node on a given testbed. This
  # method makes use of the Inventory GridService
  #
  # - name = HRN of the node to query
  # - domain = name of the testbed to query
  #
  def self.getCmcIP(hrn, domain)
    doc = nil
    begin
      doc = OMF::Services.inventory.getCmcIP(hrn, domain)
    rescue Exception => e
      MObject.error "Error trying to get CMC IP address for resource '#{hrn}' in domain '#{domain}': #{e}"
      raise ServiceError, e.message
    end

    # Parse the Reply to retrieve the control IP address
    ip = nil
    doc.root.elements.each("/CMC_IP") { |v|
      ip = v.get_text.value if !v.get_text.nil?
    }
    # If no IP address found in the reply... raise an error
    if (ip.nil?)
      doc.root.elements.each('/CMC_IP/ERROR') { |e|
        raise ServiceError, "GridService - No CMC IP address found for '#{hrn}' - Error: #{e.get_text.value}"
      }
    end
    return ip
  end

  #
  # Return the switch IP address and port of a specific node on a given testbed. This
  # method makes use of the Inventory GridService
  #
  # - name = HRN of the node to query
  # - domain = name of the testbed to query
  #
  def self.getSwitchPort(hrn, domain)
    doc = nil
    begin
      doc = OMF::Services.inventory.getSwitchPort(hrn, domain)
    rescue Exception => e
      MObject.error "Error trying to get switch IP address/port for resource '#{hrn}' in domain '#{domain}': #{e}"
      raise ServiceError, e.message
    end

    # Parse the Reply to retrieve the control IP address
    ip = nil
    doc.root.elements.each("/SWITCH_IP_PORT") { |v|
      ip = v.get_text.value if !v.get_text.nil?
    }
    # If no IP address found in the reply... raise an error
    if (ip.nil?)
      doc.root.elements.each('/SWITCH_IP_PORT/ERROR') { |e|
        raise ServiceError, "GridService - No switch IP address/port found for '#{hrn}' - Error: #{e.get_text.value}"
      }
    end
    return ip
  end

  #
  # Return the PXE image name of a specific node on a given testbed. This
  # method makes use of the Inventory GridService
  #
  # - name = HRN of the node to query
  # - domain = name of the testbed to query
  #
  def self.getPXEImage(hrn, domain)
    doc = nil
    begin
      doc = OMF::Services.inventory.getPXEImage(hrn, domain)
    rescue Exception => e
      MObject.error "Error trying to get PXE image name for resource '#{hrn}' in domain '#{domain}': #{e}"
      raise ServiceError, e.message
    end

    # Parse the Reply
    pxe = nil
    doc.root.elements.each("/PXE_IMAGE") { |v|
      pxe = v.get_text.value if !v.get_text.nil?
    }
    # If no result found in the reply... raise an error
    if (pxe.nil?)
      doc.root.elements.each('/PXE_IMAGE/ERROR') { |e|
        raise ServiceError, "GridService - No PXE image name found for '#{hrn}' - Error: #{e.get_text.value}"
      }
    end
    return pxe
  end
  
  
  #
  # Return an Array of Human Readable Names (HRN's) of all resources in a testbed.
  #
  # - url = URL to the Inventory GridService
  # - domain = the name of the testbed to query.
  #
  # [Return] an Array of node HRN's
  #
  def self.listAllNodes(domain)
    allNodes = []
    doc = nil
    begin
      doc = OMF::Services.inventory.getListOfResources(domain)
    rescue Exception => e
      MObject.error "Error trying to get list of resources for domain '#{domain}': #{e}"
      raise ServiceError, e.message
    end

    # Parse the Reply to retrieve the list of node names
    doc.root.elements.each("/RESOURCES/NODE") { |v|
      resourceName = v.get_text.value
      allNodes << resourceName
    }
    # If no resource name found in the reply... raise an error
    if allNodes.empty?
      doc.root.elements.each('/ERROR') { |e|
        MObject.error "No Resource info found for t: #{domain} - val: #{e.get_text.value}"
      }
    end
    return allNodes
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
    @header['content-type'] = "text/plain"
  end
end

#
# checks whether a string is safe to be passed to system()
#
def safeString?(str)
  (str =~ /[^0-9A-Za-z.\-_]/).nil?
end