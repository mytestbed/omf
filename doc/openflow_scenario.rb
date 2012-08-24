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

@port2ip = {
  16 => '10.0.1.18',
  21 => '10.0.1.19',
  23 => '10.0.1.20',
  15 => '10.0.1.21'
}

@port2eth = {
  16 => '00:03:2d:0d:30:c0',
  21 => '00:03:2d:0d:30:d4',
  23 => '00:03:2d:0d:30:cc',
  15 => '00:03:2d:0d:30:ce'
}

@messages = {
  create_1:  comm.create_message([type: 'openflow_slice', name: 'test1']),
  create_2:  comm.create_message([type: 'openflow_slice', name: 'test2', controller_port: '9934']),

  config_1a: comm.configure_message([{flows: {operation: 'add', device: '00:00:00:00:00:00:00:01', in_port: '16'}}]),
  config_1b: comm.configure_message([{flows: {operation: 'add', device: '00:00:00:00:00:00:00:02', in_port: '21'}}]),
  config_1c: comm.configure_message([{flows: {operation: 'add', device: '00:00:00:00:00:00:00:02', in_port: '1', eth_src: @port2eth[16]}}]),
  config_1d: comm.configure_message([{flows: {operation: 'add', device: '00:00:00:00:00:00:00:01', in_port: '1', eth_src: @port2eth[21]}}]),

  config_2a: comm.configure_message([{flows: {operation: 'add', device: '00:00:00:00:00:00:00:01', in_port: '15'}}]),
  config_2b: comm.configure_message([{flows: {operation: 'add', device: '00:00:00:00:00:00:00:02', in_port: '23'}}]),
  config_2c: comm.configure_message([{flows: {operation: 'add', device: '00:00:00:00:00:00:00:02', in_port: '1', eth_src: @port2eth[15]}}]),
  config_2d: comm.configure_message([{flows: {operation: 'add', device: '00:00:00:00:00:00:00:01', in_port: '1', eth_src: @port2eth[23]}}]),
}

comm.when_ready do
  logger.info "# CONNECTED: #{comm.jid.inspect}"
  logger.info "* Parent resource \"#{options[:uid]}\" ready for testing"

  comm.subscribe(options[:uid]) do |event|
    comm.publish(options[:uid], @messages[:create_1])
    comm.publish(options[:uid], @messages[:create_2])
  end
end

comm.on_created_message @messages[:create_1] do |message|
  child_uid = message.read_content("resource_id")
  @messages[:release_1] ||= comm.release_message([resource_id: child_uid])
  logger.info "* Child resource \"#{child_uid}\" ready for testing"

  comm.subscribe(child_uid) do
    comm.publish(child_uid, @messages[:config_1a])
    comm.publish(child_uid, @messages[:config_1b])
    comm.publish(child_uid, @messages[:config_1c])
    comm.publish(child_uid, @messages[:config_1d])
  end
end

comm.on_created_message @messages[:create_2] do |message|
  child_uid = message.read_content("resource_id")
  @messages[:release_2] ||= comm.release_message([resource_id: child_uid])
  logger.info "* Child resource \"#{child_uid}\" ready for testing"

  comm.subscribe(child_uid) do
    comm.publish(child_uid, @messages[:config_2a])
    comm.publish(child_uid, @messages[:config_2b])
    comm.publish(child_uid, @messages[:config_2c])
    comm.publish(child_uid, @messages[:config_2d])
  end
end

[@messages[:config_1a], @messages[:config_2a]].each do |config|
  comm.on_status_message config do |message|
    message.each_property do |p|
      #logger.info "#{p.attr('key')} => #{p.content.strip}"
      logger.info "#{p.attr('key')} =>"
      array = p.content.strip.split("\#<Hashie::Mash")
      array[1..-1].each {|line| logger.info line}
    end
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

  trap(:INT) do 
    comm.publish(options[:uid], @messages[:release_1])
    comm.publish(options[:uid], @messages[:release_2])
    comm.disconnect
  end
  trap(:TERM) do 
    comm.publish(options[:uid], @messages[:release_1]) 
    comm.publish(options[:uid], @messages[:release_2])
    comm.disconnect
  end
end

