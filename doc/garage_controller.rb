#!/usr/bin/env ruby

require 'omf_rc'
require 'omf_rc/resource_factory'

$stdout.sync = true


op_mode = :development

opts = {
  communication: { url: 'xmpp://garage:pw@localhost' },
  eventloop: { type: :em },
  logging: {
    level: 'info'
  #  level: 'debug',
  #  appenders: {
  #    stdout: {
  #      date_pattern: '%H:%M:%S',
  #      pattern: '%d %-5l %c{2}: %m\n',
  #      color_scheme: 'default'
  #    }
  #  }
  }
}

module OmfRc::ResourceProxy::Garage
  include OmfRc::ResourceProxyDSL

  register_proxy :garage

  hook :before_create do |garage, new_resource_type, new_resource_opts|
    new_resource_opts = Hashie::Mash.new(new_resource_opts)
    new_resource_opts.property ||= Hashie::Mash.new
    new_resource_opts.property.provider = ">> #{garage.uid}"
  end

  hook :after_create do |garage, engine|
    # new resource created
    info "Engine #{engine.uid} CREATED in #{garage.uid}"
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
  property :sn

  # before_ready hook will be called during the initialisation of the resource instance
  #
  hook :before_ready do |engine|
    # The following simulates the engine RPM, it basically says:
    # * Applying 100% throttle will increase RPM by 5000 per second
    # * Engine will reduce RPM by 250 per second when no throttle applied
    # * If RPM exceed engine's maximum RPM, the engine will blow.
    #
    OmfCommon.eventloop.every(1) do
      unless engine.property.rpm == 0
        raise 'Engine blown up' if engine.property.rpm > engine.property.max_rpm
        engine.property.rpm += (engine.property.throttle * 5000 - 250)
        engine.property.rpm = 1000 if engine.property.rpm < 1000
        if engine.property.rpm > 4000
          engine.membership.each do |m|
            engine.inform(:status, { uid: engine.uid, rpm: engine.property.rpm.to_i }, engine.membership_topics[m])
          end
        end
      end
    end
  end

  hook :after_initial_configured do |engine|
    info "Engine #{engine.uid} (SN: #{engine.property.sn}) configured using options defined in create messages."
  end

  # before_release hook will be called before the resource is fully released, shut down the engine in this case.
  #
  hook :before_release do |engine|
    # Reduce throttle to 0%
    engine.property.throttle = 0.0
    # Reduce RPM to 0
    engine.property.rpm = 0
  end

  # We want RPM to be availabe for requesting
  request :rpm do |engine|
    if engine.property.rpm > engine.property.max_rpm
      raise 'Engine blown up'
    else
      engine.property.rpm.to_i
    end
  end

  # We want throttle to be availabe for configuring (i.e. changing throttle)
  configure :throttle do |engine, value|
    engine.property.throttle = value.to_f / 100.0
  end

  request :failure do |engine|
    raise "You asked for an failure, and you got it"
  end
end

OmfCommon.init(op_mode, opts) do |el|
  OmfCommon.comm.on_connected do |comm|
    info ">>> Starting garage"

    garage = OmfRc::ResourceFactory.new(:garage, opts.merge(uid: 'garage'))

    # Disconnect garage from XMPP server, when INT or TERM signals received
    comm.on_interrupted { garage.disconnect }
  end
end
