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
        constructor: 'TestPDP',
        trust: ['adam']
      }
    }
  }
}

# Implements a simple PDP which accepts any message from a set of trusted issuers.
#
class TestPDP

  def initialize(opts = {})
    @trust = opts[:trust] || []
    puts "AUTH INIT>>> #{opts}"
  end

  def authorize(msg, &block)
    iss = msg.issuer.resource_id
    if @trust.include? iss
      puts "AUTH(#{iss}) >>> PASS"
      msg
    else
      puts "AUTH(#{iss}) >>> FAILED"
    end
  end
end

def doit(comm, el)
  init_auth_store(comm)
  comm.subscribe(:test) do |topic|
    topic.on_message do |msg|
      puts "MSG>> #{msg}"
    end

    topic.configure({foo: 1}, {issuer: 'adam'})
    el.after(1) { topic.configure({foo: 2}, {issuer: 'eve'}) }
  end
end

def init_auth_store(comm)
  root_ca = OmfCommon::Auth::Certificate.create_root

  root_ca.create_for_resource 'adam', :requester
  root_ca.create_for_resource 'eve', :requester
end

OmfCommon.init(:local, opts) do |el|
  OmfCommon.comm.on_connected do |comm|
    doit(comm, el)
  end
  el.after(3) do puts "AFTER" end
end