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

context_id = nil

comm.when_ready do
  logger.info "# CONNECTED: #{comm.jid.inspect}"
  logger.info "# Parent resource \"#{parent_uid}\" ready for testing"
  host = comm.jid.domain

  comm.subscribe(parent_uid, host) do
    message = Message.create do |v|
      v.property('type', 'openflow_slice')
      v.property('name', 'test')
    end
    logger.info message.operation.to_s+": "+(context_id = message.read_content('context_id'))
    comm.publish(parent_uid, message, host)
  end
end

comm.topic_event do |e|
  e.items.each do |item|
    message = Message.parse(item.payload)
    if message.operation == :inform
      case message.read_content("inform_type")
      when 'CREATED'
        child_uid = message.read_content("resource_id")
        logger.info "# Child resource \"#{child_uid}\" ready for testing"

        comm.subscribe(child_uid, host) do
          message = Message.request do |v|
            v.property('stats')
          end
          logger.info message.operation.to_s+": "+(context_id = message.read_content('context_id'))
          comm.publish(child_uid, message, host)
        end

      when 'STATUS'
        logger.info "status: " + (context_id_new = message.read_content('context_id'))
        message.read_element("//property").each do |p|
          logger.info "  #{p.attr('key')} => #{p.content.strip}"
        end

        #if context_id == context_id_new
        #end

     when 'FAILED'
        logger.error message.read_content("error_message")
        
      when 'RELEASED'
        logger.warn "Engine turned off (resource released)"
      end
    end
  end
end

EM.run do
  comm.connect(options[:user], options[:password], options[:server])
  trap(:INT) { comm.disconnect }
  trap(:TERM) { comm.disconnect }
end
