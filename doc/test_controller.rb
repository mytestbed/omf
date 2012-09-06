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

garage_id = options[:uid]

Logging.logger.root.level = options[:debug] ? :debug : :info
Blather.logger = logger

# We will use Comm directly, with default DSL implementaion :xmpp
comm = Comm.new(:xmpp)

garage_topic = comm.get_topic(garage_id)

garage_topic.on_message proc { |m| m.operation != :inform } do |message|
  logger.warn message
end

# messages { key: Topic }
msgs = {
  create: comm.create_message([type: 'engine']),
  request: comm.request_message([:max_rpm, {:provider => {country: 'japan'}}, :max_power]),
  request_rpm: comm.request_message([:rpm]),
  increase_throttle: comm.configure_message([throttle: 50]),
  reduce_throttle: comm.configure_message([throttle: 0]),
  test_error_handling: comm.request_message([:error]),
}

msgs[:test_error_handling].on_inform_failed do |message|
  logger.error message.read_content("reason")
end

megs[:create].on_inform_failed do |message|
  logger.error "Resource creation failed ---"
  logger.error message.read_content("reason")
end

msgs[:request].on_inform_status do |message|
  message.each_property do |p|
    logger.info "#{p.attr('key')} => #{p.content.strip}"
  end
end

msgs[:request].on_inform_failed do |message|
  logger.error message.read_content("reason")
end

msgs[:request_rpm].on_inform_status do |message|
  message.each_property do |p|
    logger.info "#{p.attr('key')} => #{p.content.strip}"
  end
end

# Triggered when new messages published to the topics I subscribed to
msgs[:create].on_inform_created do |message|
  engine_topic = comm.get_topic(message.resource_id)
  engine_id = engine_topic.id

  msgs[:release] ||= comm.release_message { |m| m.element('resource_id', engine_id) }

  msgs[:release].on_inform_released  do |message|
    logger.info "Engine (#{message.resource_id}) turned off (resource released)"
  end

  logger.info "Engine #{engine_id} ready for testing"

  engine_topic.subscribe do
    # Now subscribed to engine topic, we can ask for some information about the engine
    msgs[:request].publish engine_id

    # We will check engine's RPM
    msgs[:request_rpm].publish engine_id

    # Now we will apply 50% throttle to the engine
    msgs[:increase_throttle].publish engine_id

    comm.add_timer(5) do
      # Some time later, we want to reduce the throttle to 0, to avoid blowing up the engine
      msgs[:reduce_throttle].publish engine_id

      # Testing error handling
      msgs[:test_error_handling].publish engine_id
    end

    # 10 seconds later, we will 'release' this engine, i.e. shut it down
    comm.add_timer(10) do
      msgs[:release].publish garage_id
    end
  end
end

# Then we can register event handlers to the communicator
#
# Event triggered when connection is ready
comm.when_ready do
  logger.info "CONNECTED: #{comm.jid.inspect}"

  # We assume that a garage resource proxy instance is up already, so we subscribe to its pubsub topic
  garage_topic.subscribe do
    # If subscribed, we publish a 'create' message, 'create' a new engine for testing
    msgs[:create].publish garage_topic.id
  end
end

EM.run do
  comm.connect(options[:user], options[:password], options[:server])
  trap(:INT) { comm.disconnect }
  trap(:TERM) { comm.disconnect }
end
