#!/usr/bin/env ruby

require 'omf_rc'
require 'omf_rc/resource_factory'
require 'omf_rc/resource_proxy/openflow_slice_factory'
$stdout.sync = true

options = {
  user: 'testbed',
  password: 'pw',
  server: 'srv.mytestbed.net', # XMPP pubsub server domain
  uid: 'openflowslicefactory1',
}

EM.run do
  openflowslicefactory = OmfRc::ResourceFactory.new(:openflowslicefactory, options)
  openflowslicefactory.connect

  trap(:INT) { openflowslicefactory.disconnect }
  trap(:TERM) { openflowslicefactory.disconnect }
end
