require 'omf_common'

# Use OmfCommon.eventloop to access eventloop instance, by default it is Eventmachine
# Use OmfCommon.comm to access communicator.

def create_engine(garage)
  garage.create(:engine, { sn: 10001 }) do |reply_msg|
    if reply_msg.success?
      engine = reply_msg.resource

      engine.on_subscribed do
        info ">>> Connected to newly created resource #{reply_msg[:res_id]} with serial number #{reply_msg[:sn]}"
        on_engine_created(engine)
      end

      OmfCommon.eventloop.after(15) do
        info ">>> SENDING: to release engine"
        garage.release(engine) do |reply_msg|
          info "Engine #{reply_msg[:res_id]} released"
          OmfCommon.comm.disconnect
        end
      end
    else
      error ">>> Resource creation failed - #{reply_msg[:reason]}"
    end
  end
end

def on_engine_created(engine)
  info "> We can ask for some information about the engine"
  engine.request([:rpm, :max_rpm, :max_power, :provider])

  info "> Now we will apply 50% throttle to the engine"
  engine.configure(throttle: 50)

  # Some time later
  OmfCommon.eventloop.after(5) do
    info "> We want to reduce the throttle to 0"
    engine.configure(throttle: 0)
  end

  # Monitor all status information from the engine
  engine.on_status do |msg|
    msg.each_property do |name, value|
      info "#{name}: #{value}"
    end
  end

  engine.on_error do |msg|
    error msg[:reason]
  end

  engine.on_warn do |msg|
    warn msg[:reason]
  end
end

OmfCommon.init(:development, communication: { url: 'xmpp://bob4:pw@localhost' }) do
  OmfCommon.comm.on_connected do |comm|
    info "Connected as #{comm.jid}"

    comm.subscribe('garage') do |garage|
      unless garage.error?
        create_engine(garage)
      else
        error garage.inspect
      end

      OmfCommon.eventloop.after(30) { info 'Disconnecting ...'; comm.disconnect }
    end

    comm.on_interrupted { warn 'Interuppted...'; comm.disconnect }
  end
end
