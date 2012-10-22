#!/usr/bin/env ruby

require 'omf_rc'
require 'omf_rc/resource_factory'
$stdout.sync = true

Blather.logger = logger

opts = {
  # XMPP server domain
  server: 'localhost',
  # List of garages
  garages: ['mclaren', 'ferrari'],# Name of the garages (resource)
  # Debug mode of not
  debug: false
}

Logging.logger.root.level = :debug if opts[:debug]

module OmfRc::ResourceProxy::Garage
  include OmfRc::ResourceProxyDSL

  register_proxy :garage

  hook :before_create do |resource, new_resource_type, new_resource_opts|
    new_resource_opts.property ||= Hashie::Mash.new
    new_resource_opts.property.provider = ">> #{resource.uid}"
  end

  hook :after_create do |resource, new_resource|
    # new resource created
    logger.info resource.uid
    logger.info new_resource.uid
  end
end


module OmfRc::ResourceProxy::Engine
  include OmfRc::ResourceProxyDSL

  register_proxy :engine, :create_by => :garage

  # We can now initialise some properties which will be stored in resource's property variable.
  # A set of or request/configure methods for these properties are available automatically, so you don't have to define them again using request/configure DSL method, unless you would like to overwrite the default behaviour.
  property :max_power, :default => 676 # Set the engine maximum power to 676 bhp
  property :provider, :default => "Honda"
  property :max_rpm, :default => 12500 # Maximum RPM of the engine is 12,500
  property :rpm, :default => 1000 # Engine starts, RPM will stay at 1000 (i.e. engine is idle)
  property :throttle, :default => 0.0 # Throttle is 0% initially

  # before_ready hook will be called during the initialisation of the resource instance
  #
  hook :before_ready do |resource|
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

# We can define a new type of engine, say MP4, which extends some of the original engine methods
#
module OmfRc::ResourceProxy::Mp4
  include OmfRc::ResourceProxy::Engine
  include OmfRc::ResourceProxyDSL

  register_proxy :mp4

  extend_hook :before_ready
  extend_request :provider

  hook :before_ready do |resource|
    resource.orig_before_ready
    logger.info 'This is new before ready hook'
  end

  request :provider do |resource, args|
    "Extended provider method: " + resource.orig_request_provider(args)
  end
end

EM.run do
  garages = opts.delete(:garages)
  # Use resource factory method to initialise a new instance of garage
  garages = garages.map do |g|
    logger.info "Starting #{g}"
    garage = OmfRc::ResourceFactory.new(
      :garage,
      opts.merge(user: g, password: 'pw', uid: g)
    )
    garage.connect
    garage
  end

  # Disconnect garage from XMPP server, when these two signals received
  trap(:INT) { garages.each(&:disconnect) }
  trap(:TERM) { garages.each(&:disconnect) }
end
