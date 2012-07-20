#!/usr/bin/env ruby

require 'omf_common'
$stdout.sync = true

include OmfCommon

options = {
  user: 'bravo',
  password: 'pw',
  server: 'localhost', # XMPP pubsub server domain
  uid: 'mclaren' # The garage's name, we used the same name in the garage_controller.
}

# We will use Comm directly, with default DSL implementaion :xmpp
comm = Comm.new(:xmpp)
host = nil

# Then we can register event handlers to the communicator
#
# Event triggered when connection is ready
comm.when_ready do
  logger.info "CONNECTED: #{comm.jid.inspect}"
  host = comm.jid.domain

  # We assume that a garage resource proxy instance is up already, so we subscribe to its pubsub topic
  comm.subscribe(options[:uid], host) do |e|
    if e.error?
      comm.disconnect
    else
      # If subscribed, we publish a 'create' message, 'create' a new engine for testing
      comm.publish(
        options[:uid],
        Message.create { |v| v.property('type', 'engine') },
        host)
    end
  end
end

# Triggered when new messages published to the topics I subscribed to
comm.topic_event do |e|
  e.items.each do |item|
    begin
      # Parse the message (pubsub item payload)
      message = Message.parse(item.payload)
      # We are only interested in inform messages for the moment
      if message.operation == :inform
        inform_type = message.read_content("inform_type")
        case inform_type
        when 'CREATED'
          engine_id = message.read_content("resource_id")
          logger.info "Engine #{engine_id} ready for testing"

          comm.subscribe(engine_id, host) do
            # Now engine is ready, we can ask for some information about the engine
            comm.publish(engine_id,
                         Message.request do |v|
                           v.property('max_rpm')
                           v.property('provider') do |p|
                             p.element('country', 'japan')
                           end
                           v.property('max_power')
                         end,
                         host)

            # We will check engine's RPM every 1 second
            EM.add_periodic_timer(1) do
             comm.publish(engine_id,
                          Message.request { |v| v.property('rpm') },
                          host)
            end

            # Now we will apply 50% throttle to the engine
            comm.publish(engine_id,
                        Message.configure { |v| v.property('throttle', '50') },
                        host)

            # Some time later, we want to reduce the throttle to 0, to avoid blowing up the engine
            EM.add_timer(5) do
             comm.publish(engine_id,
                          Message.configure { |v| v.property('throttle', '0') },
                          host)
             # Testing error handling
             comm.publish(engine_id,
                          Message.request { |v| v.property('error') },
                          host)
            end

            # 20 seconds later, we will 'release' this engine, i.e. shut it down
            EM.add_timer(20) do
             comm.publish(engine_id,
                          Message.release,
                          host)
            end
          end
        when 'STATUS'
          message.read_element("//property").each do |p|
            logger.info "#{p.attr('key')} => #{p.content.strip}"
          end
        when 'FAILED'
          logger.error message.read_content("error_message")
        when 'RELEASED'
          logger.warn "Engine turned off (resource released)"
        end
      end
    rescue => e
      logger.error "#{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end

EM.run do
  comm.connect(options[:user], options[:password], options[:server])
  trap(:INT) { comm.disconnect }
  trap(:TERM) { comm.disconnect }
end
