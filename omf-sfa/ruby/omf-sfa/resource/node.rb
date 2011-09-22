
require 'omf-sfa/resource/component'
require 'omf-sfa/resource/interface'

module OMF::SFA::Resource
  
  class Node < Component
    sfa_class 'node'
    
    sfa :hardware_type, String, :inline => true, :has_many => true
    sfa :available, :boolean, :attr_value => 'now'  # <available now="true">
    sfa :sliver_type, String, :attr_value => 'name'

    sfa :interfaces, Interface, :inline => true, :has_many => true

    def initialize(*args)
      puts "NODE #{args.inspect}"
      super
      puts "NODE2"      
    end
  end
  
end # OMF::SFA

if $0 == __FILE__
  require 'rubygems'
  require 'dm-core'
  DataMapper::Logger.new($stdout, :debug)
  #DataMapper.setup(:default, :adapter => :in_memory)
  DataMapper.setup(:default, :adapter => 'yaml', :path => '/tmp/test.yaml')
  #DataMapper.setup(:default, :adapter => 'sqlite3', :path => '/tmp/test.sq3')
  
  DataMapper::Model.extra_inclusions(OMF::SFA::Resource::Base)
  
  include OMF::SFA::Resource
  OMF::Common::Loggable.init_log 'resource'

  
  
  

  

  GURN.default_prefix = "urn:publicid:IDN+mytestbed.net"
  Component.default_component_manager_id = "authority+am"

  #n = Node.create #:component_name => 'foo'
  # n.available = false
  # #n.save
  # puts n.available #object_id#inspect
  
  n2 = Node.all[0]
  puts n2,inspect # n2.methods.sort
  
  
#  puts Node.all[0].available #.object_id #.available
  exit
  
  n = Node.new 'node1'
  n.available = false
  n.sliver_type = 'raw-pc'
  n.hardware_type << :foo

  iface = Interface.new('node1:if1')
  n.interfaces << iface
  n.interfaces << iface  # should be by reference now  

  require 'omf-sfa/resource/link'  
  l = OMF::SFA::Resource::Link.new 'link1'
  l.interfaces << iface
  l.properties_add :source_id => iface.component_id
  
  doc =  Component.sfa_advertisement_xml([n, l])
  
  n.save
  puts Node.all
  #puts doc
end