#!/usr/bin/env ruby

require 'omf_common'
$stdout.sync = true

include OmfCommon

options = {
  user: 'bravo',
  password: 'pw',
  server: 'localhost', # XMPP pubsub server domain
  uid: 'mclaren', # The garage's name, we used the same name in the garage_controller.
  debug: false
}

Logging.logger.root.level = options[:debug] ? :debug : :info
Blather.logger = logger

# We will use Comm directly, with default DSL implementaion :xmpp
comm = Comm.new(:xmpp)

@messages = {
  create: comm.create_message([type: 'engine']),
  request: comm.request_message([:max_rpm, {:provider => {country: 'japan'}}, :max_power]),
  request_rpm: comm.request_message([:rpm]),
  increase_throttle: comm.configure_message([throttle: 50]),
  reduce_throttle: comm.configure_message([throttle: 0]),
  test_error_handling: comm.request_message([:error]),
}

# Then we can register event handlers to the communicator
#
# Event triggered when connection is ready
comm.when_ready do
  logger.info "CONNECTED: #{comm.jid.inspect}"

  # We assume that a garage resource proxy instance is up already, so we subscribe to its pubsub topic
  comm.subscribe(options[:uid]) do |event|
    # If subscribed, we publish a 'create' message, 'create' a new engine for testing
    comm.publish(options[:uid], @messages[:create])
  end
end

# Triggered when new messages published to the topics I subscribed to
comm.on_created_message @messages[:create] do |message|
  engine_id = message.read_content("resource_id")
  @messages[:release] ||= comm.release_message([resource_id: engine_id])
  logger.info "Engine #{engine_id} ready for testing"

  comm.subscribe(engine_id) do
    # Now engine is ready, we can ask for some information about the engine
    comm.publish(engine_id, @messages[:request])

    # We will check engine's RPM every 1 second
    comm.publish(engine_id, @messages[:request_rpm])

    # Now we will apply 50% throttle to the engine
    comm.publish(engine_id, @messages[:increase_throttle])

    # Some time later, we want to reduce the throttle to 0, to avoid blowing up the engine
    comm.add_timer(5) do
      comm.publish(engine_id, @messages[:reduce_throttle])

      # Testing error handling
      comm.publish(engine_id, @messages[:test_error_handling])
    end

    # 20 seconds later, we will 'release' this engine, i.e. shut it down
    comm.add_timer(10) do
      comm.publish(options[:uid], @messages[:release])
    end

    comm.on_released_message @messages[:release] do |message|
      logger.info "Engine turned off (resource released)"
    end
  end
end

comm.on_failed_message @messages[:test_error_handling] do |message|
  logger.error message.read_content("error_message")
end

comm.on_status_message @messages[:request] do |message|
  message.each_property do |p|
    logger.info "#{p.attr('key')} => #{p.content.strip}"
  end
end

comm.on_status_message @messages[:request_rpm] do |message|
  message.each_property do |p|
    logger.info "#{p.attr('key')} => #{p.content.strip}"
  end
end


EM.run do
  comm.connect(options[:user], options[:password], options[:server])
  trap(:INT) { comm.disconnect }
  trap(:TERM) { comm.disconnect }
end
