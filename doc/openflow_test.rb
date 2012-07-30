#!/usr/bin/env ruby

require 'omf_common'
$stdout.sync = true

include OmfCommon

options = {
  user: 'user',
  password: 'pw',
  server: 'srv.mytestbed.net', # XMPP pubsub server domain
  uid: 'flowvisor',
}

# We will use Comm directly, with default DSL implementaion :xmpp_blather
comm = Comm.new(:xmpp)
host = nil

comm.when_ready do
  logger.info "CONNECTED: #{comm.jid.inspect}"
  host = comm.jid.domain

  comm.subscribe(options[:uid], host) do |e|
    if e.error?
      comm.disconnect(host)
    else
      comm.publish(
        options[:uid],
        Message.create do |v| 
          v.property('type', 'openflow_slice')
          v.property('name', 'vs2')
        end,
        host
      )
      #comm.publish(
      #  options[:uid],
      #  Message.configure do |v|
      #    v.property('flowvisor') do |p|
      #      p.element('host', 'localhost')
      #    end
      #  end,
      #  host
      #)
      comm.publish(
        options[:uid],
        Message.request do |v|
          v.property('slices')
      #    v.property('devices')
          v.property('flowSpaces')
      #    v.property('deviceInfo') do |p|
      #      p.element('pid', '1')
      #    end
      #    v.property('deviceStats') do |p|
      #      p.element('pid', '1')
      #    end
        end,
        host
      )
    end
  end
end

comm.topic_event do |e|
  e.items.each do |item|
    begin
      message = Message.parse(item.payload)
      if message.operation == :inform
        inform_type = message.read_content("inform_type")
        case inform_type
        when 'CREATED'
          openflow_slice_id = message.read_content("resource_id")
          logger.info "Openflow Slice #{openflow_slice_id} ready for testing"

          comm.subscribe(openflow_slice_id, host) do
            comm.publish(
              openflow_slice_id,
              Message.request do |v|
                v.property('info')
            #    v.property('stats')
              end,
              host
            )
            #comm.publish(
            #  openflow_slice_id,
            #  Message.configure do |v|
            #    v.property('passwd') do |p|
            #      p.element('new_value', 'openflow')
            #    end
            #    v.property('change') do |p|
            #      p.element('key', 'contact_email')
            #      p.element('value', 'vs2@foo.com')
            #    end
            #    v.property('createSlice') do |p|
            #      p.element('arg1', 'vs2')
            #      p.element('arg2', 'openflow')
            #      p.element('arg3', 'tcp:127.0.0.1:9934')
            #      p.element('arg4', 'vs2@fo.com')
            #    end
            #    v.property('deleteSlice') do |p|
            #      p.element('arg1', 'vs2')
            #    end
            #    v.property('addFlowSpace') do |p|
            #      p.element('dpid', '1')
            #      p.element('priority', '10')
            #      p.element('match', 'OFMatch[in_port=1]')
            #      p.element('actions', 'Slice:vs1=4')
            #    end
            #    v.property('removeFlowSpace') do |p|
            #      p.element('id', '17')
            #    end
            #    v.property('changeFlowSpace') do |p|
            #      p.element('id', '18')
            #      p.element('dpid', '1')
            #      p.element('priority', '10')
            #      p.element('match', 'OFMatch[in_port=25]')
            #      p.element('actions', 'Slice:vs1=4')
            #    end
            #  end,
            #  host
            #)
            EM.add_timer(5) do
              comm.publish(openflow_slice_id, Message.release, host)
              logger.info "Openflow Slice #{openflow_slice_id} has been deleted"
            end
          end
        when 'STATUS'
          message.read_element("//property").each do |p|
            logger.info "#{p.attr('key')} => #{p.content.strip}"
          end
        end
      end
    end
  end
end

EM.run do
  comm.connect(options[:user], options[:password], options[:server])
  trap(:INT) { comm.disconnect }
  trap(:TERM) { comm.disconnect }
end
