#!/usr/bin/env ruby

require 'omf_common'
$stdout.sync = true

include OmfCommon

options = {
  user: 'user',
  password: 'pw',
  server: 'srv.mytestbed.net', # XMPP pubsub server domain
}

parent_uid = 'flowvisor'
child_uid = nil

# We will use Comm directly, with default DSL implementaion :xmpp_blather
comm = Comm.new(:xmpp)
host = nil

comm.when_ready do
  logger.info "# CONNECTED: #{comm.jid.inspect}"
  logger.info "* Parent resource \"#{parent_uid}\" ready for testing"
  host = comm.jid.domain

  comm.subscribe(parent_uid, host) do
    message = Message.create do |v|
      v.property('type', 'openflow_slice')
      v.property('name', 'vs2')
    end
    logger.info message.operation.to_s+": "+ message.read_content('context_id')
    comm.publish(parent_uid, message, host)
  end
end

comm.topic_event do |e|
  e.items.each do |item|
    message = Message.parse(item.payload)
    if message.operation == :inform
      case message.read_content("inform_type")
      when 'CREATED'
        logger.info "created: " + message.read_content('context_id')

        child_uid = message.read_content("resource_id")
        logger.info "* Child resource \"#{child_uid}\" ready for testing"

        comm.subscribe(child_uid, host) do
          message = Message.configure do |v|
            v.property('addFlow') do |p|
              p.element('device', '00:00:00:00:00:00:00:01')
              p.element('port', '30')
            end
            v.property('deleteFlow') do |p|
              p.element('device', '00:00:00:00:00:00:00:01')
              p.element('port', '30')
            end
          end
          logger.info message.operation.to_s+": "+ message.read_content('context_id')
          comm.publish(child_uid, message, host)

          EM.add_timer(10) do
            message = Message.release
            logger.info message.operation.to_s+": "+ message.read_content('context_id')
            comm.publish(child_uid, message, host)
          end
        end

      when 'STATUS'
        logger.info "status: " + message.read_content('context_id')
        message.read_element("//property").each do |p|
          logger.info "  #{p.attr('key')} => #{p.content.strip}"
        end

     when 'FAILED'
        logger.error "failed: " + message.read_content('context_id')
        logger.error message.read_content("error_message")
        
      when 'RELEASED'
        logger.warn "released: " + message.read_content('context_id')

        child_uid = message.read_content("resource_id")
        logger.warn "* Child resource \"#{child_uid}\" is released"
      end
    end
  end
end

EM.run do
  comm.connect(options[:user], options[:password], options[:server])
  trap(:INT) { comm.disconnect }
  trap(:TERM) { comm.disconnect }
end

