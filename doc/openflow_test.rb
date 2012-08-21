#!/usr/bin/env ruby

require 'omf_common'
$stdout.sync = true

include OmfCommon

options = {
  user: 'user',
  password: 'pw',
  server: 'srv.mytestbed.net', # XMPP pubsub server domain
  uid: 'flowvisor',
  debug: false
}

Logging.logger.root.level = options[:debug] ? :debug : :info
Blather.logger = logger

comm = Comm.new(:xmpp)

@messages = {
  create: comm.create_message([type: 'openflow_slice', name: 'test1']),
  config: comm.configure_message([flows: {operation: 'remove', port: '21', device: '00:00:00:00:00:00:00:01'}]),
}

comm.when_ready do
  logger.info "# CONNECTED: #{comm.jid.inspect}"
  logger.info "* Parent resource \"#{options[:uid]}\" ready for testing"

  comm.subscribe(options[:uid]) do |event|
    comm.publish(options[:uid], @messages[:create])
  end

  comm.add_timer(10) do
    comm.publish(options[:uid], @messages[:release])
  end
end

comm.on_created_message @messages[:create] do |message|
  child_uid = message.read_content("resource_id")
  @messages[:release] ||= comm.release_message([resource_id: child_uid])
  logger.info "* Child resource \"#{child_uid}\" ready for testing"

  comm.subscribe(child_uid) do
    comm.publish(child_uid, @messages[:config])
  end
end

comm.on_status_message do |message|
  message.each_property do |p|
    logger.info "#{p.attr('key')} => #{p.content.strip}"
  end
end

comm.on_failed_message do |message|
  logger.error message.read_content("error_message")
end

comm.on_released_message do |message|
  logger.info "Child resource released"
end

EM.run do
  comm.connect(options[:user], options[:password], options[:server])
  trap(:INT) { comm.disconnect }
  trap(:TERM) { comm.disconnect }
end
