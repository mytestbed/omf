#!/usr/bin/env ruby

require 'omf_common'
$stdout.sync = true

include OmfCommon

options = {
  user: 'bravo',
  password: 'pw',
  server: 'localhost',
  uid: 'mclaren',
  pubsub_host: 'pubsub',
}

comm = Comm.new(:xmpp_blather)
host = nil

# For simplicity, use comm instance directly
comm.when_ready do
  logger.info "CONNECTED: #{comm.jid.inspect}"
  host = "#{options[:pubsub_host]}.#{comm.jid.domain}"

  # We assume the node where RC runs started already
  comm.subscribe(options[:uid], host) do |e|
    if e.error?
      comm.disconnect(host)
    else
      comm.publish(
        options[:uid],
        Message.create { |v| v.property('type', 'engine') },
        host)
    end
  end
end

# Fired when messages published to the nodes I subscribed to
comm.node_event do |e|
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
            # Engine is ready, get some information about the engine
            comm.publish(
              engine_id,
              Message.request do |v|
                v.property('max_rpm')
                v.property('provider')
                v.property('max_power')
              end.sign,
              host
            )

            # Checking RPM every 1 second
            EM.add_periodic_timer(1) do
              comm.publish(engine_id,
                           Message.request { |v| v.property('rpm') }.sign,
                           host)
            end

            # Apply 50% throttle
            comm.publish(engine_id,
                         Message.configure { |v| v.property('throttle', '50') }.sign,
                         host)

            # Some time we want to reduce throttle to 0, avoid blowing up the engine
            EM.add_timer(5) do
              comm.publish(engine_id,
                           Message.configure { |v| v.property('throttle', '0') }.sign,
                           host)
            end

            # 30 seconds later, we will 'release' this engine

            EM.add_timer(20) do
              comm.publish(engine_id,
                           Message.release.sign,
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
  trap(:INT) { comm.disconnect(host) }
  trap(:TERM) { comm.disconnect(host) }
end

