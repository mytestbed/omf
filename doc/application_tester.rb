#!/usr/bin/env ruby

require 'omf_common'
$stdout.sync = true

def run_test(app)
  # Set up inform message handler to print inform messages
  app.on_inform do |m|
    case m.itype
    when 'STATUS'
      if m[:status_type] == 'APP_EVENT'
        info "APP_EVENT #{m[:event]} from app #{m[:app]} - msg: #{m[:msg]}"
      end
    when 'ERROR'
      error m[:reason]
    when 'WARN'
      warn m[:reason]
    end
  end

  # Configure the 'binary_path' and 'parameters' properties of the App Proxy
  app.configure(binary_path: "/bin/ping",
                parameters: { :target => { :value => 'nicta.com.au' }})

  # Start the application 2 seconds later
  OmfCommon.eventloop.after 2 do
    app.configure(state: :running)
  end

  # Stop the application another 10 seconds later
  OmfCommon.eventloop.after 12 do
    app.configure(state: :stopped)
  end
end

OmfCommon.init(:development,
               communication: { url: 'xmpp://localhost' },
               logging: { level: { default: 'info' } }) do
  OmfCommon.comm.on_connected do |comm|
    info "Test application >> Connected to XMPP as #{comm.conn_info}"

    # Subscribe to the proxy topic
    comm.subscribe('app_test') do |app|
      if app.error?
        error app.inspect
      else
        # Now subscribed, run the test
        run_test(app)
      end
    end

    comm.on_interrupted { comm.disconnect }
  end
end
