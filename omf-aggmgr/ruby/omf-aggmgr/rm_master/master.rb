#
# Implements a service to manage the resources on multiple heterogenous testbeds
#

require 'omf-aggmgr/ogs/gridService'

class MasterService < GridService
  
  name 'master' # used to register/mount the service, the service's url will be based on it
  info 'Service to manage the resources on multiple heterogenous testbeds'
  @@config = nil # will be populated by call to configure from superclass

  s_info "Reserve some resources on some testbeds"
  s_param :resourceSet, 'resourceSet', 'XML specification of the set of resources to reserve'
  s_param :date, 'date', 'XML date specification for this reservation'
  s_param :username, 'userName', 'username for this reservation'
  service 'makeReservation' do |req, res|
    # Retrieve the request parameter
    resSet = getParam(req, :resourceSet)
    dateSpec = getParam(req, :date)
    uName = getParam(req, :username)
    # Check resource availabilities 
    # If Resources are available for the given date
    #    Allocate them and create a token for this allocation
    #    Return the token + success confirmation to caller
    # If not return failure message to caller
  end
  
  s_info "Access a previously reserved set of resources"
  s_param :resourceSet, 'resourceSet', 'XML specification of the set of resources to access'
  s_param :token, 'token', 'Token to access this set of resources'
  service 'access' do |req, res|
      # Retrieve the request parameter
      resSet = getParam(req, :resourceSet)
      tk = getParam(req, :token)
      root = REXML::Element.new("ACCESS")
      # Check if the resources are still available
      why = checkResAvailability(resSet, tk)
      if (why == nil)
        # If so return list of resources (description+contact+ticket) to the caller
        ticket = generateTicket(resSet, tk)
        el = REXML::Element.new("TICKET")
        el.text = ticket
        root.add_element(el)
      else
        # if not return WHY to the caller
        # (a resource that has been previousle reserved SHOULD be still available here
        # this is just to trap the rare cases when it's not, e.g. hardware failure, or
        # any other decisions from the testbed admin to remove this resources)     
        el = REXML::Element.new("CANCELLED")
        el.text = why
        root.add_element(el)
      end
      setResponse(res, root)
  end
  
  s_info "Retrieve the list of available resources for a given testbeds"
  service 'listResources' do |req, res|
  end
  
  s_info "Retrieve the list of available testbeds"
  service 'listTestbeds' do |req, res|
    list = @@config['default']['testbedList']
    root = REXML::Element.new("LIST")
    list.each { |e|
      el = REXML::Element.new("TESTBED")
      el.add_attribute("name",e['name'])
      el.add_attribute("comment",e['comment'])
      root.add_element(el)
    }
    setResponse(res, root)
  end
  
  # Configure the service through a hash of options
  #
  def self.configure(config)
    @@config = config
  end
  
  def self.checkResAvailability(resSet, tk)
    return nil
  end
  
  def self.generateTicket(resSet, tk)
    return "000stub000ticket000"
  end
  
end
