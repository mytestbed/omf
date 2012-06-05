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
end


module OmfRc::ResourceProxy::Engine
  include OmfRc::ResourceProxyDSL

  register_proxy :engine

  # before_ready hook will be called during the initialisation of the resource instance
  #
  register_hook :before_ready do |resource|
    resource.metadata.max_power ||= 676 # Set the engine maximum power to 676 bhp
    resource.metadata.provider ||= 'Honda' # Engine provider defaults to Honda
    resource.metadata.max_rpm ||= 12500 # Maximum RPM of the engine is 12,500
    resource.metadata.rpm ||= 1000 # After engine starts, RPM will stay at 1000 (i.e. engine is idle)
    resource.metadata.throttle ||= 0.0 # Throttle is 0% initially

    # The following simulates the engine RPM, it basically says:
    # * Applying 100% throttle will increase RPM by 5000 per second
    # * Engine will reduce RPM by 250 per second when no throttle applied
    # * If RPM exceed engine's maximum RPM, the engine will blow.
    #
    EM.add_periodic_timer(1) do
      unless resource.metadata.rpm == 0
        raise 'Engine blown up' if resource.metadata.rpm > resource.metadata.max_rpm
        resource.metadata.rpm += (resource.metadata.throttle * 5000 - 250)
        resource.metadata.rpm = 1000 if resource.metadata.rpm < 1000
      end
    end
  end

  # before_release hook will be called before the resource is fully released, shut down the engine in this case.
  #
  register_hook :before_release do |resource|
    # Reduce throttle to 0%
    resource.metadata.throttle = 0.0
    # Reduce RPM to 0
    resource.metadata.rpm = 0
  end

  # We want RPM to be availabe for requesting
  register_request :rpm do |resource|
    if resource.metadata.rpm > resource.metadata.max_rpm
      raise 'Engine blown up'
    else
      resource.metadata.rpm.to_i
    end
  end

  # We want some default metadata to be availabe for requesting
  %w(provider max_power max_rpm).each do |attr|
    register_request attr do |resource|
      resource.metadata[attr]
    end
  end

  # We want throttle to be availabe for configuring (i.e. changing throttle)
  register_configure :throttle do |resource, value|
    resource.metadata.throttle = value.to_f / 100.0
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
