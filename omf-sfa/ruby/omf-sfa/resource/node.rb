
require 'omf-sfa/resource/component'
require 'omf-sfa/resource/interface'

module OMF::SFA::Resource
  
  class Node < Component
    sfa_class 'node'
    
    sfa :hardware_type, String, :inline => true, :has_many => true
    sfa :available, :boolean, :attr_value => 'now'  # <available now="true">
    sfa :sliver_type, String, :attr_value => 'name'

    sfa :interfaces, Interface, :inline => true, :has_many => true

  end
  
end # OMF::SFA

if $0 == __FILE__
  include OMF::SFA::Resource
  
  OMF::Common::Loggable.init_log 'resource'

  OMF::SFA::Resource::GURN.default_prefix = "urn:publicid:IDN+mytestbed.net"
  OMF::SFA::Resource::Component.default_component_manager_id = "authority+am"
  
  n = OMF::SFA::Resource::Node.new 'node1'
  n.available = false
  n.sliver_type = 'raw-pc'
  n.hardware_type << :foo

  iface = OMF::SFA::Resource::Interface.new('node1:if1')
  n.interfaces << iface
  n.interfaces << iface  # should be by reference now  

  require 'omf-sfa/resource/link'  
  l = OMF::SFA::Resource::Link.new 'link1'
  l.interfaces << iface
  l.properties << OMF::SFA::Resource::LinkProperty.create(:source_id => iface.component_id)
  
  doc =  OMF::SFA::Resource::Component.sfa_advertisement_xml([n, l])
  
  puts doc
end