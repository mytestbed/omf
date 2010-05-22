#!/usr/bin/ruby -I/usr/share/omf-common-5.3

require 'omf-common/omfPubSubMessage.rb'
require "pubsubTester"

@slice = "omf.nicta.slice1"
@tester = PubSubTester.new("omf@norbit.npc.nicta.com.au", "omf", "norbit.npc.nicta.com.au", "norbit.npc.nicta.com.au", true)

def delete(node, sliver)
  msg = @tester.newcmd(:cmdType => "DELETE_SLIVER", :target => "#{node}", :slicename => "#{@slice}", :slivername => "#{sliver}", 
  :slivertype => 'openvz')
  @tester.send("/OMF/system/#{node}", msg)

  msg = @tester.newcmd(:cmdType => "NOOP", :target => "#{node}")
  @tester.send("/OMF/system/#{node}", msg)
end

delete("node30", "omf.nicta.node30_1")
delete("node30", "omf.nicta.node30_2")

delete("node29", "omf.nicta.node29_1")
delete("node29", "omf.nicta.node29_2")

delete("node28", "omf.nicta.node28_1")
delete("node28", "omf.nicta.node28_2")

