# OMF_VERSIONS = 6.0

def create_engine(garage)
  garage.create(:engine) do |reply_msg|
    if reply_msg.success?
      engine = reply_msg.resource

      engine.on_subscribed do
        info ">>> Connected to newly created resource #{reply_msg[:res_id]}"
        on_engine_created(engine)
      end
    else
      error ">>> Resource creation failed - #{reply_msg[:reason]}"
    end
  end
end

def on_engine_created(engine)
  info ">>> SENDING REQUEST"
  # We can ask for some information about the engine
  engine.request([:rpm, :max_rpm, :max_power, :provider])

  # Now we will apply 50% throttle to the engine
  info ">>> SENDING CONFIGURE throttle 50%"
  engine.configure(throttle: 50)

  # Some time later, we want to reduce the throttle to 0, to avoid blowing up the engine
  after(5) do
    info ">>> SENDING CONFIGURE throttle 0%"
    engine.configure(throttle: 0)
  end

  every(1) do
    engine.request([:rpm])
  end

  # Monitor all status information from the engine
  engine.on_status do |msg|
    msg.each_property do |name, value|
      info "#{name} => #{value}"
    end
  end

  engine.on_error do |msg|
    error msg.reason
  end

  engine.on_warn do |msg|
    warn msg.reason
  end
end

OmfCommon.comm.subscribe('garage') do |garage|
  unless garage.error?
    create_engine(garage)
  else
    error garage.inspect
  end

  after(20) { info 'Disconnecting ...'; OmfCommon.comm.disconnect }
end
