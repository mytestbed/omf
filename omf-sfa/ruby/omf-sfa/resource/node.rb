
require 'omf-sfa/resource/component'

module OMF::SFA::Resource
  
  class Node < Component
    rspec_class 'node'
    
    rspec :hardware_type, :type => :string, :attr_value => :name, :is_functional => false
    rspec :available, :type => :boolean, :attr_value => :name
    rspec :sliver_type, :attr_value => :name

  end
  
end # OMF::SFA

if $0 == __FILE__
  OMF::Common::Loggable.init_log 'resource'

  OMF::SFA::Resource::Node.default_component_id = "urn+xxx"
  n = OMF::SFA::Resource::Node.new
  n.available = false
  n.add_hardware_type :foo
  
  doc =  
  n.to_xml doc
  puts doc
end