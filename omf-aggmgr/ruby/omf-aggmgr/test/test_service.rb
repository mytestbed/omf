#!/usr/bin/env ruby

require 'omf-common/servicecall'
require 'omf-common/omfVersion'
ROOT = "OMF_#{OMF::Common::MM_VERSION()}"

#Jabber::debug = true

def run
  connection = OMF::XMPP::Connection.new("dom1", "test5", "123")
  connection.connect
  puts "Client connection status = #{connection.connected?}"

#  dom1 = OMF::ServiceCall.add_domain(:type => :http, :uri => "http://localhost:5051")
  dom1 = OMF::ServiceCall.add_domain(:type => :xmpp, :uri => "dom1",
                                     :user => "test5", :password => "123")
  OMF::Services::XmppEndpoint.connection = connection
  OMF::Services::XmppEndpoint.sender_id ="test5"
  OMF::Services::XmppEndpoint.pubsub_selector { |opts|
    if opts.nil?
      slice = nil; hrn = nil;
    else
      hrn = opts["hrn"] || opts[:hrn] || opts["name"] || opts[:name]
      slice = opts["sliceID"] || opts[:sliceID]
    end

    if slice.nil?
      "/#{ROOT}/system"
    elsif hrn.nil?
      "/#{ROOT}/#{slice}"
    else
      "/#{ROOT}/#{slice}/#{hrn}"
    end
  }

  service = ARGV[0]
  method = ARGV[1]

  {"service" => service,
    "method" => method }.each_pair do |k,v|
    if v.nil?
      puts "What #{k} to call?"
      exit 1
    end
  end

  result = OMF::Services.send(service).send(method, *ARGV[2..-1])

  if not result.nil?
    puts result.to_s
  else
    puts "No return value"
  end
end

run if __FILE__ == $PROGRAM_NAME
