#!/usr/bin/ruby -I/usr/share/omf-common-5.3

require 'omf-common/omfPubSubMessage.rb'
require "pubsubTester"

tester = PubSubTester.new("omf@norbit.npc.nicta.com.au", "omf", "norbit.npc.nicta.com.au", "norbit.npc.nicta.com.au", true)

#tester.create("/OMF/system/norbit.npc.nicta.com.au")
#tester.create("/OMF/omf.nicta.slice1/resources/omf.nicta.node30_3")
#tester.create("/OMF/omf.nicta.slice1/resources")
#tester.create("/OMF/system/node30")

11.times { |n|
  puts "/OMF/omf.nicta.slice1/resources/#{n}"
  begin
   tester.create("/OMF/omf.nicta.slice1/resources/#{n}")
 rescue
 end
}
