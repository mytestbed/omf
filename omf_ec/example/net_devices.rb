# @comm is default communicator defined in script runner
#
@node = @comm.get_topic(`hostname`.chomp)

@node.on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'FAILED' } do |message|
  logger.error message
end

device_request = @comm.request_message([:devices])

device_request.on_inform_status do |message|
  @devices = message.read_property('devices').items

  logger.info <<-LOG
DEVICES ->
#{@devices.map { |item| "Name: #{item.name}, Driver: #{item.driver}, Proxy: #{item.proxy}"}.join("\n") }
  LOG

  first_wlan = @devices.find { |v| v.proxy == 'wlan' }
  first_eth = @devices.find { |v| v.proxy == 'net' }

  wlan_create = @comm.create_message([type: first_wlan.proxy, hrn: first_wlan.name])
  eth_create = @comm.create_message([type: first_eth.proxy, hrn: first_eth.name])

  wlan_create.on_inform_created do |message|
    @wlan = @comm.get_topic(message.resource_id)

    @wlan.subscribe do
      wlan_p = @comm.request_message([:link, :ip_addr])

      wlan_p.on_inform_status do |message|
        freq = message.read_property(:link).freq
        ip_addr = message.read_property(:ip_addr)
        logger.info "WLAN : #{freq}, #{ip_addr}"
      end

      wlan_p.publish @wlan.id
    end
  end

  eth_create.on_inform_created do |message|
    @eth = @comm.get_topic(message.resource_id)
    @eth.on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'FAILED' } do |message|
      logger.error message.read_content(:reason)
    end

    @eth.subscribe do
      eth_ip = @comm.request_message([:ip_addr])

      eth_ip.on_inform_status do |m|
        logger.info "ETH #{m.read_property(:ip_addr)}"
      end

      eth_ip_conf = @comm.configure_message([{ip_addr: '192.168.7.1'}])

      eth_ip.on_inform_status do |m|
        logger.info "ETH #{m.read_property(:ip_addr)}"
      end

      eth_ip.publish @eth.id
      eth_ip_conf.publish @eth.id
    end
  end

  wlan_create.publish @node.id
  eth_create.publish @node.id
end

@comm.when_ready do
  logger.info "CONNECTED: #{@comm.jid.inspect}"

  @node.subscribe do
    device_request.publish @node.id
  end
end
