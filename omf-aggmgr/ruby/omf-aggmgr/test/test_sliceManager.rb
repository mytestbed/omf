#!/usr/bin/env ruby

require 'omf-common/servicecall'
require 'omf-common/omfVersion'
ROOT = "OMF_#{OMF::Common::MM_VERSION()}"

#Jabber::debug = true

def run
  connection = OMF::XMPP::Connection.new("dom1", "test_sliceManager", "123")
  connection.connect
  OMF::Services::XmppEndpoint.sender_id = "test_sliceManager"
  OMF::Services::XmppEndpoint.connection=connection
  OMF::Services::XmppEndpoint.pubsub_selector { |opts|
    if opts.nil?
      slice = nil; hrn = nil;
    else
      hrn = opts["hrn"] || opts[:hrn] || opts["name"] || opts[:name]
      slice = opts["sliceID"] || opts[:sliceID] || opts[:sliceName] || opts["sliceName"]
    end

    if slice.nil?
      "/#{ROOT}/system"
    elsif hrn.nil?
      "/#{ROOT}/#{slice}"
    else
      "/#{ROOT}/#{slice}/#{hrn}"
    end
  }


  OMF::ServiceCall.add_domain(:type => :xmpp,
                              :uri =>  "dom1",
                              :user => "test",
                              :password => "123")

  slice_name = ARGV[1]
  resources = ARGV[2..-1]

  case ARGV[0]
  when "create"
    p OMF::Services.sliceManager.createSlice(slice_name, "dom2")
  when "subscribe"
    xml = OMF::Services.sliceManager.subscribeToSlice(slice_name, "dom2", "norbit")
    p xml.to_s
  when "associate"
    p OMF::Services.sliceManager.associateResourcesToSlice(slice_name,
                                                           resources.join(','),
                                                           "dom2")
  when "deassociate"
    p "DE"
    p OMF::Services.sliceManager.deassociateResourcesFromSlice(slice_name,
                                                               resources,join(','),
                                                               "dom2")
  when "delete"
    OMF::Services.sliceManager.deleteSlice(slice_name, "dom2")
  when "list"
    r = OMF::Services.sliceManager.getResourceList(slice_name, "dom2")
    if r.kind_of? REXML::Document
      p r.elements["resources"].get_text.to_s.split(',')
    elsif r.kind_of? String
      p r
    end
  end
end

if __FILE__ == $PROGRAM_NAME then run; end
