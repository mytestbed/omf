#!/usr/bin/env ruby

abort "Please use Ruby 1.9.3 or higher" if RUBY_VERSION < "1.9.3"

require 'rubygems'
require 'omf_common'

unless ARGV[0] && ARGV[1]
  puts "Missing argument: The credential to connect to your XMPP(Openfire) server and id of your Resource Controller"
  puts "usage: rc_alice_check.rb <credential xmpp://user:password@localhost> <id of resource proxy>"
  exit 2
end

user = ARGV[0]
resource_id = ARGV[1]

everything_ok = false

OmfCommon.init(:development, communication: { url: user }) do
  OmfCommon.comm.on_connected do |comm|
    info "Connected as #{comm.jid}"

    comm.subscribe(resource_id) do |res|
      unless res.error?
        res.request([:uid]) do |reply_msg|
          unless reply_msg.error?
            info "Resource UID >> #{reply_msg[:uid]}"
            info "Resource type >> #{reply_msg[:type]}"

            everything_ok = true
          else
            error res.inspect
          end
        end
      else
        error res.inspect
      end

      OmfCommon.eventloop.after(5) do
        if everything_ok
          info "Resource #{resource_id} is up and running"
        else
          error "Resource #{resource_id} is NOT running properly"
        end
        comm.disconnect
      end
    end

    comm.on_interrupted { warn 'Interuppted...'; comm.disconnect }
  end
end
