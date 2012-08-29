#!/usr/bin/ruby -I/usr/share/omf-common-5.4

require 'omf-common/communicator/omfPubSubMessage.rb'
require "pubsubTester"
require 'omf-common/omfVersion'
ROOT = "OMF_#{OMF::Common::MM_VERSION()}"

tester = PubSubTester.new("omf@norbit.npc.nicta.com.au", "omf", "norbit.npc.nicta.com.au", "norbit.npc.nicta.com.au", true)

#tester.create("/#{ROOT}/system/norbit.npc.nicta.com.au")
#tester.create("/#{ROOT}/omf.nicta.slice1/resources/omf.nicta.node30_3")
#tester.create("/#{ROOT}/omf.nicta.slice1/resources")
#tester.create("/#{ROOT}/system/node30")

11.times { |n|
  puts "/#{ROOT}/omf.nicta.slice1/resources/#{n}"
  begin
   tester.create("/#{ROOT}/omf.nicta.slice1/resources/#{n}")
 rescue
 end
}
