# OMF_VERSIONS = 6.0

#msgs = {
#  request_port: @comm.request_message([port: {name: 'tun0', information: 'netdev-tunnel/get-port'}]),
#  configure_port: @comm.configure_message([port: {name: 'tun0', remote_ip: '138.48.3.201', remote_port: '39505'}]),
#}

def create_switch(ovs)
  ovs.create(:virtual_openflow_switch, {name: "test"}) do |reply_msg|
    if !reply_msg.itype.start_with? "ERROR" #success?
      switch = reply_msg.resource

      switch.on_subscribed do
        info ">>> Connected to newly created switch #{reply_msg[:res_id]} with name #{reply_msg[:name]}"
        on_switch_created(switch)
      end

      after(10) do
        ovs.release(switch) do |reply_msg|
          info ">>> Released switch #{reply_msg[:res_id]}"
        end
      end
    else
      error ">>> Switch creation failed - #{reply_msg[:reason]}"
    end
  end
end

def on_switch_created(switch)

  switch.configure(ports: {operation: 'add', name: 'tun0', type: 'tunnel'}) do |reply_msg|
    info "> Switch configured ports: #{reply_msg[:ports]}"
    switch.configure(port: {name: 'tun0', remote_ip: '138.48.3.201', remote_port: '39505'}) do |reply_msg|
      info "> Switch configured port: #{reply_msg[:port]}"
    end
  end

  # Monitor all status, error or warn information from the switch
  #switch.on_status do |msg|
  #  msg.each_property do |name, value|
  #    info "#{name} => #{value}"
  #  end
  #end
  switch.on_error do |msg|
    error msg[:reason]
  end
  switch.on_warn do |msg|
    warn msg[:reason]
  end
end

OmfCommon.comm.subscribe('ovs') do |ovs|
  unless ovs.error?
    create_switch(ovs)
  else
    error ovs.inspect
  end

  after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end
