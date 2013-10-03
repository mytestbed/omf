#!/usr/bin/env ruby
#
# This stand alone program is exercising a few authorization scenarios.
#
# Usage: ruby -I .

EX_DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
TOP_DIR = File.join(EX_DIR, '..')
$: << File.join(TOP_DIR, 'lib')

begin; require 'json/jwt'; rescue Exception; end
require 'omf_common'

OP_MODE = :development

opts = {
  communication: {
    auth: {
      authenticate: true,
      pdp: {
        require: 'omf_common/auth/pdp/rete_pdp',
        constructor: 'OmfCommon::Auth::PDP::RetePDP'
      }
    }
  }
}

def doit(comm)
  init_auth_store(comm)
  comm.subscribe(:test) do |topic|
    topic.on_message do |msg|
      puts "MSG>> #{msg}"
    end

    topic.configure({foo: 1})
  end
end

def init_auth_store(comm)
  root_ca = OmfCommon::Auth::Certificate.create_root
  cert = root_ca.create_for_resource 'tester1', :tester, frcp_uri: comm.local_address
  puts ">>>>> #{cert.addresses}"
end

OmfCommon.init(:local, opts) do |el|
  OmfCommon.comm.on_connected do |comm|
    doit(comm)
  end
  el.after(3) do puts "AFTER" end
end