#!/usr/bin/env ruby

require 'omf_rc'
require 'omf_rc/resource_factory'
require 'omf_rc/resource_proxy/flowvisor'
require 'omf_rc/resource_proxy/openflow_virtual_switch'
$stdout.sync = true

options = {
  user: 'testbed',
  password: 'pw',
  server: '203.143.170.208', # XMPP pubsub server domain
  uid: 'flowvisor1',
}

EM.run do
  flowvisor = OmfRc::ResourceFactory.new(:flowvisor, options)
  flowvisor.connect

  trap(:INT) { flowvisor.disconnect }
  trap(:TERM) { flowvisor.disconnect }
end
