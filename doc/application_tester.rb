#!/usr/bin/env ruby

require 'omf_common'
$stdout.sync = true

include OmfCommon

options = {
  user: 'app_proxy_tester',
  password: '123',
  server: 'localhost', # Pubsub pubsub server domain
  uid: 'app_test' # Name of the application resource (see applicaiton_controller.rb)
}

app_id = options[:uid]

comm = Comm.new(:xmpp)

# Ask our communicator to give us the topic to which the Application
# Proxy is subscribed
app_topic = comm.get_topic(app_id)

# For any 'inform' message posted on that topic...
# if it is an event from the application, log it as information
# if it is an error/warning from the Application Proxy, log it accordingly
app_topic.on_message  do |m|
  if m.operation == :inform
    case m.read_content("inform_type")
    when 'STATUS'
      if m.read_property("status_type") == 'APP_EVENT'
        logger.info "APP_EVENT #{m.read_property('event')} "+
        "from app #{m.read_property("app")} - msg: #{m.read_property("msg")}"
      end
    when 'ERROR'
      logger.error m.read_content('reason') if m.read_content("inform_type") == 'ERROR'
    when 'WARN'
      logger.warn m.read_content('reason') if m.read_content("inform_type") == 'WARN'
    end
  end
end

# Here we construct the different messages that we will publish later when we 
# will interact with the Application proxy
msgs = {
  # request the OS platform on which the App Proxy is running
  req_platform: comm.request_message([:platform]),
  # configure the 'binary_path' property of the App Proxy
  conf_path: comm.configure_message([binary_path: "/bin/ping"]),
  # configure the available parameters for the application handled by the App Proxy
  conf_parameters: comm.configure_message([parameters: {
    :timestamp => {:type => 'Boolean', :cmd => '-D', :mandatory => false},
    :target => {:type => 'String', :cmd => '', :mandatory => true, :default => 'localhost', :order => 2},
    :count => {:type => 'Numeric', :cmd => '-c', :mandatory => true, :default =>3, :order => 1},
  }]),
  # update the value of some parameters
  update_param: comm.configure_message([parameters: {
    :target => {:value => 'nicta.com.au'},
    :timestamp => {:value => true}
  }]),
  # ask the App Proxy to run the application
  run_application: comm.configure_message([state: :run])
}

# Register a block of commands to handle all 'inform' messages
# published as replies to our 'req_platform' 
msgs[:req_platform].on_inform_status do |m|
  m.each_property do |p|
    logger.info "#{p.attr('key')} => #{p.content.strip}"
  end
end


# Then we can register event handlers to the communicator
#
# Event triggered when connection is ready
comm.when_ready do
  logger.info "CONNECTED: #{comm.jid.inspect}"

  # We assume that a application resource proxy instance is up already, 
  # so we subscribe to its pubsub topic
  app_topic.subscribe do
    # If subscribed, we start publishing messages some messages
    # to interact with our Application Proxy
    msgs[:req_platform].publish app_topic.id
    sleep 1
    msgs[:conf_path].publish app_topic.id
    sleep 1
    msgs[:conf_parameters].publish app_topic.id
    sleep 1
    msgs[:run_application].publish app_topic.id
    sleep 2
    msgs[:update_param].publish app_topic.id
    sleep 1
    msgs[:run_application].publish app_topic.id
    sleep 2
  end
end

EM.run do
  comm.connect(options[:user], options[:password], options[:server])
  trap(:INT) { comm.disconnect }
  trap(:TERM) { comm.disconnect }
end
