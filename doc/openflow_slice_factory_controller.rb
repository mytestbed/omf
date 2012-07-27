#!/usr/bin/env ruby

require 'omf_rc'
require 'omf_rc/resource_factory'
require 'omf_rc/resource_proxy/openflow_slice_factory'
require 'omf_rc/resource_proxy/openflow_slice'
$stdout.sync = true

options = {
  user: 'testbed',
  password: 'pw',
  server: 'srv.mytestbed.net', # XMPP pubsub server domain
  uid: 'flowvisor',
}

EM.run do
  openflowslicefactory = OmfRc::ResourceFactory.new(:openflow_slice_factory, options)
  openflowslicefactory.connect

  trap(:INT) { openflowslicefactory.disconnect }
  trap(:TERM) { openflowslicefactory.disconnect }
end
