#!/usr/bin/ruby -I/usr/share/omf-common-5.4

require 'omf-common/communicator/omfPubSubMessage.rb'
require "pubsubTester"

tester = PubSubTester.new("omf@norbit.npc.nicta.com.au", "omf", "norbit.npc.nicta.com.au", "norbit.npc.nicta.com.au", true)

#msg = tester.newcmd(:cmdType => "CREATE_SLIVER", :target => "norbit.npc.nicta.com.au")
#msg = tester.newcmd(:cmdType => "KILL", :target => "norbit.npc.nicta.com.au", :appID => 0, :value => 9)
# msg = tester.newcmd(:cmdType => "CREATE_SLIVER", :target => "norbit.npc.nicta.com.au", :slicename => 'omf.nicta.slice1', :resname => '8', :slivertype => 'openvz', :commaddr => 'norbit.npc.nicta.com.au')
msg = tester.newcmd(:cmdType => "DELETE_SLIVER", :target => "norbit.npc.nicta.com.au", :resname => '8', :slicename => 'omf.nicta.slice1', :slivertype => 'openvz')


tester.send("/OMF/system/omf.nicta.node30", msg)


msg = tester.newcmd(:cmdType => "NOOP", :target => "norbit.npc.nicta.com.au")
tester.send("/OMF/system/omf.nicta.node30", msg)
