# OMF_VERSIONS = 6.0
require 'omf_common'

opts = {
  communication: {
    url: 'amqp://localhost',
  }
}

# $stdout.sync = true
# Logging.appenders.stdout(
  # 'my_format',
  # :layout => Logging.layouts.pattern(:date_pattern => '%H:%M:%S',
                                     # :pattern => '%d %5l %c{2}: %m\n',
                                     # :color_scheme => 'none'))
# Logging.logger.root.appenders = 'my_format'
# Logging.logger.root.level = :debug if opts[:debug]

# Environment setup
#OmfCommon.init(:developement, opts) 
OmfCommon.init(:local) 



def create_engine(garage)
  garage.create(:engine, name: 'mp4') do |msg|
    if msg.success?
      engine = msg.resource
      on_engine_created(engine, garage)
    else
      logger.error "Resource creation failed - #{msg[:reason]}"
    end
  end
end


# This is an alternative version of creating a new engine.
# We create teh message first without sending it, then attach various
# response handlers and finally publish it.
#
# TODO: This is most likely NOT working yet
#
def create_engine2
  msg = garage.create_message('mp4')
  msg.on_created do |engine, emsg|
    on_engine_created(engine, garage)
  end
  msg.on_created_failed do |fmsg|
      logger.error "Resource creation failed - #{msg[:reason]}"
  end
  msg.publish
end

# This method is called whenever a new engine has been created by the garage.
#
# @param [Topic] engine Topic representing the created engine
# 
def on_engine_created(engine, garage)
  # Monitor all status information from teh engine
  engine.on_inform_status do |msg|
    msg.each_property do |name, value|
      logger.info "#{name} => #{value}"
    end
  end

  engine.on_inform_failed do |msg|
    logger.error msg.read_content("reason")
  end

  # Send a request for specific properties
  puts ">>> SENDING REQUEST"
  engine.request([:max_rpm, {:provider => {country: 'japan'}}, :max_power]) do |msg|
  #engine.request([:max_rpm, :max_power])
  #engine.request() do |msg|
    puts ">>> REPLY #{msg.inspect}"
  end
            
              


  return 
  
  # Now we will apply 50% throttle to the engine
  engine.configure(throttle: 50)

  # Some time later, we want to reduce the throttle to 0, to avoid blowing up the engine
  engine.after(5) do
    engine.configure(throttle: 0)
    
    # While we are at it, also test error handling
    engine.request([:error]) do |msg|
      if msg.success?
        logger.error "Expected unsuccessful reply"
      else
        logger.info "Received expected fail message - #{msg[:reason]}"
      end
    end
  end

  # 10 seconds later, we will 'release' this engine, i.e. shut it down
  #engine.after(10) { release_engine(engine, garage) }
end

def release_engine(engine, garage)
  logger.info "Time to release engine #{engine}"
  garage.release engine do |rmsg|
    puts "===> ENGINE RELEASED: #{rmsg}"
  end
end

OmfCommon.eventloop.run do |el|
  OmfCommon.comm.on_connected do |comm|
    
    # Create garage proxy
    load File.join(File.dirname(__FILE__), '..', '..', 'omf_rc', 'example', 'garage_controller.rb')
    garage_inst = OmfRc::ResourceFactory.create(:garage, hrn: :garage_1)
    
    # Get handle on existing entity
    comm.subscribe('garage_1') do |garage|
    
      garage.on_inform_failed do |msg|
        logger.error msg
      end
      # wait until garage topic is ready to receive
      garage.on_subscribed do
        create_engine(garage)
      end
    end
    
    el.after(20) { el.stop }
  end
end


puts "DONE"

