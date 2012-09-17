#!/usr/bin/env ruby

require 'omf_rc'
require 'omf_rc/resource_factory'
$stdout.sync = true

options = {
  user: 'alpha',
  password: 'pw',
  server: 'localhost', # XMPP server domain
  uid: 'mclaren', # Id of the garage (resource)
}

module OmfRc::ResourceProxy::Garage
  include OmfRc::ResourceProxyDSL

  register_proxy :garage

  # before_create hook will be called before parent creates the child resource. (in the context of parent resource)
  #
  # the optional block will have access to three variables:
  # * resource: the parent resource itself
  # * new_resource_type: a string or symbol represents the new resource to be created
  # * new_resource_options: the options hash to be passed to the new resource
  #
  # this hook enable us to do things like:
  # * validating child resources: e.g. if parent could create this new resource
  # * setting up default child properties based on parent's property value
  hook :before_create do |resource, new_resource_type, new_resource_options|
    if new_resource_type.to_sym == :engine
      logger.info "Resource type engine is allowed"
    else
      raise "Go away, I can't create #{new_resource_type}"
    end
    new_resource_options.property ||= Hashie::Mash.new
    new_resource_options.property.provider = "Cosworth #{resource.uid}"
  end

  hook :after_create do |resource, new_resource|
    # new resource created
    logger.info resource.uid
    logger.info new_resource.uid
  end
end


module OmfRc::ResourceProxy::Engine
  include OmfRc::ResourceProxyDSL

  register_proxy :engine

  # before_ready hook will be called during the initialisation of the resource instance
  #
  hook :before_ready do |resource|
    # We can now initialise some properties which will be stored in resource's property variable.
    # A set of or request/configure methods for these properties are available automatically, so you don't have to define them again using request/configure DSL method, unless you would like to overwrite the default behaviour.
    resource.property.max_power ||= 676 # Set the engine maximum power to 676 bhp
    resource.property.provider ||= 'Honda' # Engine provider defaults to Honda
    resource.property.max_rpm ||= 12500 # Maximum RPM of the engine is 12,500
    resource.property.rpm ||= 1000 # After engine starts, RPM will stay at 1000 (i.e. engine is idle)
    resource.property.throttle ||= 0.0 # Throttle is 0% initially

    # The following simulates the engine RPM, it basically says:
    # * Applying 100% throttle will increase RPM by 5000 per second
    # * Engine will reduce RPM by 250 per second when no throttle applied
    # * If RPM exceed engine's maximum RPM, the engine will blow.
    #
    EM.add_periodic_timer(1) do
      unless resource.property.rpm == 0
        raise 'Engine blown up' if resource.property.rpm > resource.property.max_rpm
        resource.property.rpm += (resource.property.throttle * 5000 - 250)
        resource.property.rpm = 1000 if resource.property.rpm < 1000
      end
    end
  end

  hook :after_initial_configured do |resource|
    logger.info "New maximum power is now: #{resource.property.max_power}"
  end

  # before_release hook will be called before the resource is fully released, shut down the engine in this case.
  #
  hook :before_release do |resource|
    # Reduce throttle to 0%
    resource.property.throttle = 0.0
    # Reduce RPM to 0
    resource.property.rpm = 0
  end

  # We want RPM to be availabe for requesting
  request :rpm do |resource|
    if resource.property.rpm > resource.property.max_rpm
      raise 'Engine blown up'
    else
      resource.property.rpm.to_i
    end
  end

  request :provider do |resource, args|
    "#{resource.property.provider} - #{args.country}"
  end

  # We want throttle to be availabe for configuring (i.e. changing throttle)
  configure :throttle do |resource, value|
    resource.property.throttle = value.to_f / 100.0
  end

  request :error do |resource|
    raise "You asked for an error, and you got it"
  end
end

EM.run do
  # Use resource factory method to initialise a new instance of garage
  garage = OmfRc::ResourceFactory.new(:garage, options)
  # Let garage connect to XMPP server
  garage.connect

  # Disconnect garage from XMPP server, when these two signals received
  trap(:INT) { garage.disconnect }
  trap(:TERM) { garage.disconnect }
end
