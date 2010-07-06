#!/usr/bin/ruby -I/usr/share/omf-common-5.3

require 'omf-common/omfPubSubMessage.rb'
require "pubsubTester"

@slice = "omf.nicta.slice1"
@tester = PubSubTester.new("omf@norbit.npc.nicta.com.au", "omf", "norbit.npc.nicta.com.au", "norbit.npc.nicta.com.au", true)

# hrn = HRN of RM that created the sliver
def delete(hrn, sliver)
  msg = @tester.newcmd(:cmdType => "DELETE_SLIVER", :target => "#{hrn}", :slicename => "#{@slice}", :slivername => "#{sliver}", 
  :slivertype => 'openvz')
  @tester.send("/OMF/system/#{hrn}", msg)

  msg = @tester.newcmd(:cmdType => "NOOP", :target => "#{hrn}")
  @tester.send("/OMF/system/#{hrn}", msg)
end

delete("omf.nicta.node30", "omf.nicta.node30_1")
delete("omf.nicta.node30", "omf.nicta.node30_2")

delete("omf.nicta.node29", "omf.nicta.node29_1")
delete("omf.nicta.node29", "omf.nicta.node29_2")

delete("omf.nicta.node28", "omf.nicta.node28_1")
delete("omf.nicta.node28", "omf.nicta.node28_2")

