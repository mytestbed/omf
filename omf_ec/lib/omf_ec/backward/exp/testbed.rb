comm = OmfCommon.comm

testbed_topic = comm.get_topic('testbed')

msgs = {
  create: comm.create_message([type: 'application']),
  req_platform: comm.request_message([:platform]),
  conf_path: comm.configure_message([binary_path: @cmd]),
  run_application: comm.configure_message([state: :run])
}

msgs[:create].on_inform_creation_ok do |message|
  app_topic = comm.get_topic(message.res_id)
  app_topic.subscribe do
    msgs[:req_platform].publish app_topic.id
    sleep 1
    msgs[:conf_path].publish app_topic.id
    sleep 1
    msgs[:run_application].publish app_topic.id
  end

  app_topic.on_message  do |m|
    if m.operation == :inform
      case m.read_content("itype")
      when 'STATUS'
        if m.read_property("status_type") == 'APP_EVENT'
          after (2) { comm.disconnect } if m.read_property("event") =~ /DONE.(OK|ERROR)/
          puts m.read_property("msg")
        end
      when 'ERROR'
        logger.error m.read_content('reason') if m.read_content("itype") == 'ERROR'
      when 'WARN'
        logger.warn m.read_content('reason') if m.read_content("itype") == 'WARN'
      end
    end
  end
end

msgs[:req_platform].on_inform_status do |m|
  m.each_property do |p|
    logger.info "#{p.attr('key')} => #{p.content.strip}"
  end
end

testbed_topic.subscribe do
  msgs[:create].publish testbed_topic.id
end
