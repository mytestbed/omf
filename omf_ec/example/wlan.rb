# OMF_VERSIONS = 6.0

# @comm is default communicator defined in script runner
#
# now plan my actions

@node = {
  :topic => @comm.get_topic('testbed_foo.node26'), # Assume the node is up, with pubsub topic testbed_foo.node26 created
  :load_module => @comm.configure_message([:load_module => { name: 'ath9k', unload: 'ath9k'}]),
  :get_devices => @comm.request_message([:devices, :uid])
}

@node[:topic].on_message lambda {|m| m.operation == :inform && m.read_content('inform_type') == 'FAILED' } do |message|
  logger.error message
end

@node[:load_module].on_inform_status do |message|
  logger.info "#{@node[:topic].id} #{message.read_property(:load_module)}"
end

@node[:get_devices].on_inform_status do |message|
  logger.info "#{message.read_property('uid')} reports:"
  devices = message.read_property('devices').items

  logger.info <<-LOG
#{@node[:topic].id} DEVICES ->
#{devices.map { |item| "Name: #{item.name}, Driver: #{item.driver}, Proxy: #{item.proxy}"}.join("\n") }
  LOG

  wlan = devices.find { |v| v.name == 'phy1' }

  if wlan
    logger.info "#{@node[:topic].id} Wifi device found: #{wlan.name}"
    logger.info "#{@node[:topic].id} Try to setup #{wlan.name} using master mode"

    create = @comm.create_message([type: 'wlan', hrn: 'wlan1'])

    create.on_inform_created do |message|
      interface = @comm.get_topic(message.resource_id)

      interface.subscribe do
        set_mode = @comm.configure_message([:mode => {phy: wlan.name, mode: "managed", essid: "foo_ap"}])

        set_ip = @comm.configure_message([:ip_addr => "192.168.10.2/24"])

        set_mode.on_inform_status do |message|
          logger.info "#{@node[:topic].id} has been setup"
          set_ip.publish interface.id
        end

        set_mode.publish interface.id

        set_ip.on_inform_status do |message|
          logger.info "#{@node[:topic].id} #{wlan.name} 'wlan0' IP: " + message.read_property(:ip_addr)
        end

        [set_mode, set_ip].each do |v|
          v.on_inform_failed do |message|
            logger.error "#{@node[:topic].id} reason: " + message.read_content('reason')
          end
        end

        release = @comm.release_message { |v| v.element(:resource_id, interface.id) }

        release.on_inform_released do |message|
          logger.info "#{@node[:topic].id} #{wlan.name} 'wlan0' released."
        end

        @comm.add_timer(10) do
          release.publish @node[:topic].id
        end
      end
    end

    create.publish @node[:topic].id
  end
end

@comm.when_ready do
  logger.info "CONNECTED: #{@comm.jid.inspect}"

  @node[:topic].subscribe do
    @node[:load_module].publish @node[:topic].id

    @comm.add_timer(5) do
      @node[:get_devices].publish @node[:topic].id
    end
  end
end
