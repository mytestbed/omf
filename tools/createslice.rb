#!/usr/bin/ruby -I/usr/share/omf-common-5.3

require 'omf-common/omfPubSubMessage.rb'
require "pubsubTester"

slice = "omf.nicta.slice1"
resource = "node30"

tester = PubSubTester.new("omf@norbit.npc.nicta.com.au", "omf", "norbit.npc.nicta.com.au", "norbit.npc.nicta.com.au", true)

begin
  tester.create("/OMF/#{slice}")
  tester.create("/OMF/#{slice}/resources")
rescue
end

1.upto(3) { |n|
  begin
    tester.create("/OMF/#{slice}/resources/#{n}")
  rescue
  end
  msg = tester.newcmd(:cmdType => "CREATE_SLIVER", :target => "norbit.npc.nicta.com.au", :slicename => "#{slice}", :resname => "omf.nicta.#{resource}", :slivertype => 'openvz', :commaddr => 'norbit.npc.nicta.com.au')
  tester.send("/OMF/system/#{resource}", msg)
}
msg = tester.newcmd(:cmdType => "NOOP", :target => "#{resource}")
tester.send("/OMF/system/#{resource}", msg)


#msg = tester.newcmd(:cmdType => "CREATE_SLIVER", :target => "norbit.npc.nicta.com.au")
#msg = tester.newcmd(:cmdType => "KILL", :target => "norbit.npc.nicta.com.au", :appID => 0, :value => 9)
# msg = tester.newcmd(:cmdType => "CREATE_SLIVER", :target => "norbit.npc.nicta.com.au", :slicename => 'omf.nicta.slice1', :resname => '8', :slivertype => 'openvz', :commaddr => 'norbit.npc.nicta.com.au')
#msg = tester.newcmd(:cmdType => "DELETE_SLIVER", :target => "norbit.npc.nicta.com.au", :resname => '8', :slicename => 'omf.nicta.slice1', :slivertype => 'openvz')


#msg = tester.newcmd(:cmdType => "NOOP", :target => "norbit.npc.nicta.com.au")
#tester.send("/OMF/system/node30", msg)
