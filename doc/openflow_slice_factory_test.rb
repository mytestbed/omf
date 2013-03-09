# OMF_VERSIONS = 6.0

def create_slice(flowvisor)
  flowvisor.create(:openflow_slice, {name: "test"}) do |reply_msg|
    if !reply_msg.itype.start_with? "ERROR" #success?
      slice = reply_msg.resource

      slice.on_subscribed do
        info ">>> Connected to newly created slice #{reply_msg[:res_id]} with name #{reply_msg[:name]}"
        on_slice_created(slice)
      end

      after(10) do
        flowvisor.release(slice) do |reply_msg|
          info ">>> Released slice #{reply_msg[:res_id]}"
        end
      end
    else
      error ">>> Slice creation failed - #{reply_msg[:reason]}"
    end
  end
end

def on_slice_created(slice)

  slice.request([:name]) do |reply_msg|
    info "> Slice requested name: #{reply_msg[:name]}"
  end

  slice.configure(flows: [{operation: 'add', device: '00:00:00:00:00:00:00:01', eth_dst: '11:22:33:44:55:66'},
                          {operation: 'add', device: '00:00:00:00:00:00:00:01', eth_dst: '11:22:33:44:55:77'}]) do |reply_msg|
    info "> Slice configured flows:"
    reply_msg.read_property('flows').each do |flow|
      logger.info "   #{flow}"
    end
  end

  # Monitor all status, error or warn information from the slice
  #slice.on_status do |msg|
  #  msg.each_property do |name, value|
  #    info "#{name} => #{value}"
  #  end
  #end
  slice.on_error do |msg|
    error msg[:reason]
  end
  slice.on_warn do |msg|
    warn msg[:reason]
  end
end

OmfCommon.comm.subscribe('flowvisor') do |flowvisor|
  unless flowvisor.error?
    create_slice(flowvisor)
  else
    error flowvisor.inspect
  end

  after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end
