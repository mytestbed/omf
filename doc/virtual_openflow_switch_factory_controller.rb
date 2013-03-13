#!/usr/bin/env ruby

require 'omf_rc'
require 'omf_rc/resource_factory'
require 'omf_rc/resource_proxy/virtual_openflow_switch'
require 'omf_rc/resource_proxy/virtual_openflow_switch_factory'


$stdout.sync = true


op_mode = :development

opts = {
  communication: { url: 'xmpp://ovs:pw@srv.mytestbed.net' },
  eventloop: { type: :em },
  logging: {
    level: 'info'
  #  level: 'debug',
  #  appenders: {
  #    stdout: {
  #      date_pattern: '%H:%M:%S',
  #      pattern: '%d %-5l %c{2}: %m\n',
  #      color_scheme: 'default'
  #    }
  #  }
  }
}

OmfCommon.init(op_mode, opts) do |el|
  OmfCommon.comm.on_connected do |comm|
    info ">>> Starting ovs"

    ovs = OmfRc::ResourceFactory.new(:virtual_openflow_switch_factory, opts.merge(uid: 'ovs'))

    # Disconnect garage from XMPP server, when INT or TERM signals received
    comm.on_interrupted { ovs.disconnect }
  end
end
