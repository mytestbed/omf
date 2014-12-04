#!/usr/bin/env ruby
#
# ruby example/auth_test_2.rb inside omf_common dir
#
require 'bundler'
Bundler.require

require 'omf_common'

env_opts = {
  environment: 'development',
  communication: {
    local_address: 'adam',
    url: 'amqp://localhost',
    auth: {
      authenticate: true,
      pdp: {
        require: 'omf_common/auth/pdp/job_service',
        constructor: 'OmfCommon::Auth::PDP::JobService',
        slice: 'slice_a'
      }
    }
  },
  logging: {
    level: { default: 'debug' },
    appenders: {
      stdout: {
        level: :info,
        date_pattern: '%H:%M:%S',
        pattern: '%d %5l %c{2}: %m\n',
        color_scheme: 'default'
      }
    }
  }
}

def init_auth_store
  root_ca = OmfCommon::Auth::Certificate.create_root

  root_ca.create_for_resource 'adam', :requester
  root_ca.create_for_resource 'eve', :requester
end


OmfCommon.init(:development, env_opts) do |event_loop|
  OmfCommon.comm.on_connected do |comm|
    init_auth_store

    assert = OmfCommon::Auth::Assertion.new(
      type: 'json',
      iss: 'vip',
      content: 'adam can use slice slice_a'
    )

    comm.subscribe(:test) do |topic|
      topic.on_message do |msg|
        info "MSG >> #{msg}"
      end

      topic.configure(
        { foo: 1 },
        { issuer: 'adam',
          assert: assert }
      )

      event_loop.after(1) do
        topic.configure(
          { foo: 2 },
          { issuer: 'eve' }
        )
      end
    end
  end
end
