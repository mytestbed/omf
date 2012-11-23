#!/usr/bin/env ruby

require 'omf_rc'
require 'omf_rc/resource_factory'
require 'omf_rc/resource_proxy/application.rb'
$stdout.sync = true

options = {
  user: 'app_proxy_test',
  password: '123',
  server: 'localhost', # Pubsub server domain
  uid: 'app_test', # Id of the resource
}

EM.run do
  # Use resource factory method to initialise a new instance of the resource
  my_application = OmfRc::ResourceFactory.new(:application, options)
  # Let the resource to XMPP server
  my_application.connect

  # Disconnect the resource from Pubsub server, when these two signals received
  trap(:INT) { my_application.disconnect }
  trap(:TERM) { my_application.disconnect }
end
