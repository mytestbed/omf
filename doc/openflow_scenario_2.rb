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
context_id = []


# We will use Comm directly, with default DSL implementaion :xmpp_blather
comm = Comm.new(:xmpp)

comm.when_ready do
  logger.info "# CONNECTED: #{comm.jid.inspect}"
  logger.info "* Parent resource \"#{parent_uid}\" ready for testing"

  comm.subscribe(parent_uid) do
    %w{test1 test2}.each do |name|
      message = Message.create do |v|
        v.property('type', 'openflow_slice')
        v.property('name', name)
        v.property('controller_port', '9934') if name=='test2'
      end
      context_id << message.read_content('context_id')
      logger.info message.operation.to_s+": "+message.read_content('context_id')
      comm.publish(parent_uid, message)
    end 
  end
end

comm.topic_event do |e|
  e.items.each do |item|
    message = Message.parse(item.payload)
    if message.operation == :inform
      case message.read_content("inform_type")
      when 'CREATED'
        logger.info "created: " + (cur_context_id = message.read_content('context_id'))

        ports = cur_context_id == context_id[0] ? [16, 21] : [23, 21]
        
        child_uid = message.read_content("resource_id")
        logger.info "* Child resource \"#{child_uid}\" ready for testing"

        comm.subscribe(child_uid) do
          ports.each do |port|
            message = Message.configure do |v|
              v.property('flows') do |p|
                p.element('action', 'add')
                p.element('port', port)
                p.element('device', "00:00:00:00:00:00:00:01")
                p.element('ip_dst', ports[0] == 16 ? "10.0.1.18" : "10.0.1.20" ) if port == 21
              end
            end
            logger.info message.operation.to_s+": "+ message.read_content('context_id')
            comm.publish(child_uid, message)
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

