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
  create_1:  comm.create_message([type: 'openflow_slice', name: 'test1']),
  create_2:  comm.create_message([type: 'openflow_slice', name: 'test2', controller_port: '9934']),
  config_1a: comm.configure_message([{flows: {operation: 'add', port: '16', device: '00:00:00:00:00:00:00:01'}}]),
  config_1b: comm.configure_message([{flows: {operation: 'add', port: '21', device: '00:00:00:00:00:00:00:01', ip_dst: '10.0.1.18'}}]),
  config_2a: comm.configure_message([{flows: {operation: 'add', port: '23', device: '00:00:00:00:00:00:00:01'}}]),
  config_2b: comm.configure_message([{flows: {operation: 'add', port: '21', device: '00:00:00:00:00:00:00:01', ip_dst: '10.0.1.20'}}])
}

comm.when_ready do
  logger.info "# CONNECTED: #{comm.jid.inspect}"
  logger.info "* Parent resource \"#{options[:uid]}\" ready for testing"

  comm.subscribe(options[:uid]) do |event|
    comm.publish(options[:uid], @messages[:create_1])
    comm.publish(options[:uid], @messages[:create_2])
  end

  comm.add_timer(10) do
    comm.publish(options[:uid], @messages[:release_1])
    comm.publish(options[:uid], @messages[:release_2])
  end
end

comm.on_created_message @messages[:create_1] do |message|
  child_uid = message.read_content("resource_id")
  @messages[:release_1] ||= comm.release_message([resource_id: child_uid])
  logger.info "* Child resource \"#{child_uid}\" ready for testing"

  comm.subscribe(child_uid) do
    comm.publish(child_uid, @messages[:config_1a])
    comm.publish(child_uid, @messages[:config_1b])
  end
end

comm.on_created_message @messages[:create_2] do |message|
  child_uid = message.read_content("resource_id")
  @messages[:release_2] ||= comm.release_message([resource_id: child_uid])
  logger.info "* Child resource \"#{child_uid}\" ready for testing"

  comm.subscribe(child_uid) do
    comm.publish(child_uid, @messages[:config_2a])
    comm.publish(child_uid, @messages[:config_2b])
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
  child_uid = message.read_content("resource_id")
  logger.info "Child resource \"#{child_uid}\" released"
end

EM.run do
  comm.connect(options[:user], options[:password], options[:server])
  trap(:INT) { comm.disconnect }
  trap(:TERM) { comm.disconnect }
end

