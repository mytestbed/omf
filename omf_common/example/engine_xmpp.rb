# OMF_VERSIONS = 6.0
require 'omf_common'

OmfCommon::Eventloop.init(type: :em)

def create_engine(garage)
  garage.create(:engine, name: 'bob') do |msg|
    if msg.success?
      info ">>> Connected to newly created resource #{msg.inspect}"
      on_engine_created(msg.resource_address)
    else
      error ">>> Resource creation failed - #{msg[:reason]}"
    end
  end
end

# This method is called whenever a new engine has been created by the garage.
#
# @param [Topic] engine Topic representing the created engine
#
def on_engine_created(engine_resource_address)
  OmfCommon.eventloop.after(3) do
    OmfCommon.comm.subscribe(engine_resource_address) do |engine|
      # Monitor all status information from teh engine
      engine.on_status do |msg|
        msg.each_property do |name, value|
          logger.info "#{name} => #{value}"
        end
      end

      engine.on_error do |msg|
        logger.error msg.read_content("reason")
      end

      # Send a request for specific properties
      info ">>> SENDING REQUEST"

      engine.request([:max_rpm, :max_power]) do |msg|
        info ">>> REPLY #{msg.inspect}"
      end

      # Now we will apply 50% throttle to the engine
      engine.configure(throttle: 50)

      # Some time later, we want to reduce the throttle to 0, to avoid blowing up the engine
      OmfCommon.eventloop.after(5) do
        engine.configure(throttle: 0)
      end
    end
  end
end

def release_engine(engine, garage)
  logger.info "Time to release engine #{engine}"
  garage.release engine do |rmsg|
    puts "===> ENGINE RELEASED: #{rmsg}"
  end
end

OmfCommon.eventloop.run do |el|
  OmfCommon::Comm.init(type: :xmpp, username: 'alpha', password: 'pw', server: 'localhost')

  OmfCommon.comm.on_connected do |comm|
    info "Connected as #{OmfCommon.comm.jid}"

    comm = OmfCommon.comm
    comm.subscribe('garage') do |garage|
      create_engine(garage)
    end

    el.after(20) { el.stop }
  end
end

info "DONE"
