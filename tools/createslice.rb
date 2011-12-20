#!/usr/bin/ruby -I/usr/share/omf-common-5.4

require 'omf-common/communicator/omfPubSubMessage.rb'
require "pubsubTester"

@slice = "omf.nicta.slice1"
@tester = PubSubTester.new("omf@norbit.npc.nicta.com.au", "omf", "norbit.npc.nicta.com.au", "norbit.npc.nicta.com.au", true)

def create (hrn, ipaddr)
  msg = @tester.newcmd(:cmdType => "CREATE_SLIVER", :target => "#{hrn}", :slicename => "#{@slice}", 
  :resname => "#{hrn}", :slivertype => 'openvz', :commaddr => 'norbit.npc.nicta.com.au', 
  :sliveraddress => "#{ipaddr}", :slivernameserver => '10.0.0.200')
  @tester.send("/OMF/system/#{hrn}", msg)
  msg = @tester.newcmd(:cmdType => "NOOP", :target => "#{hrn}")
  @tester.send("/OMF/system/#{hrn}", msg)
  # TODO: these nodes will be created by the RM in the future
  # creating 5 slice nodes per host
  1.upto(5) { |n|
    begin
      @tester.create("/OMF/#{@slice}/resources/#{hrn}_#{n}")
    rescue
    end
  }
end

begin
  @tester.create("/OMF/#{@slice}")
  @tester.create("/OMF/#{@slice}/resources")
rescue
end

# create two slivers on node 30
create("omf.nicta.node30", "10.0.1.30")
create("omf.nicta.node30", "10.0.2.30")

# create two slivers on node 29
create("omf.nicta.node29", "10.0.1.29")
create("omf.nicta.node29", "10.0.2.29")

# create two slivers on node 28
create("omf.nicta.node28", "10.0.1.28")
create("omf.nicta.node28", "10.0.2.28")



# msg = tester.newcmd(:cmdType => "CREATE_SLIVER", :target => "norbit.npc.nicta.com.au")
# msg = tester.newcmd(:cmdType => "KILL", :target => "norbit.npc.nicta.com.au", :appID => 0, :value => 9)
# msg = tester.newcmd(:cmdType => "CREATE_SLIVER", :target => "norbit.npc.nicta.com.au", :slicename => 'omf.nicta.slice1', :resname => '8', :slivertype => 'openvz', :commaddr => 'norbit.npc.nicta.com.au')
# msg = tester.newcmd(:cmdType => "DELETE_SLIVER", :target => "norbit.npc.nicta.com.au", :resname => '8', :slicename => 'omf.nicta.slice1', :slivertype => 'openvz')
# msg = tester.newcmd(:cmdType => "NOOP", :target => "norbit.npc.nicta.com.au")
# tester.send("/OMF/system/node30", msg)
