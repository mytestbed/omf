#!/usr/bin/env ruby

require 'omf-common/servicecall'

Jabber::debug = true

def run
  puts "Hello"

  OMF::ServiceCall.add_domain(:type => :xmpp,
                              :uri =>  "dom1",
                              :user => "test",
                              :password => "123")

  resources = [ "omf.nicta.node1",
                "omf.nicta.node2",
                "omf.nicta.node3" ]
  if ARGV[0] == "create"
    p OMF::Services.sliceManager.createSlice("hello", "dom2")


    p OMF::Services.sliceManager.associateResourcesToSlice("hello",
                                                           resources.join(','),
                                                           "dom2")

    p OMF::Services.sliceManager.subscribeToSlice("hello", "dom2", "norbit")
  else
    OMF::Services.sliceManager.deleteSlice("hello", "dom2")
  end
end

if __FILE__ == $PROGRAM_NAME then run; end
