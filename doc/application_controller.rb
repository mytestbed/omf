#!/usr/bin/env ruby

require 'omf_rc'
require 'omf_rc/resource_proxy/application'
$stdout.sync = true

OmfCommon.init(:development,
               communication: { url: 'xmpp://localhost' },
               logging: { level: { default: 'info' } }) do
  OmfCommon.comm.on_connected do |comm|
    info "Application controller >> Connected to XMPP server as #{comm.conn_info}"
    # Use resource factory method to initialise a new instance of the resource
    app = OmfRc::ResourceFactory.create(:application, uid: 'app_test')
    # Disconnect the resource from Pubsub server, when 'INT' signals received
    comm.on_interrupted { app.disconnect }
  end
end

