
require 'omf-sfa/resource/component'

module OMF::SFA::Resource
  
  class Interface < Component
    
    #property :hardware_type, String
    #property :available, Boolean, :default => false
    property :sliver_type, String
    property :available, String
    property :role, String
    belongs_to :node
    belongs_to :network    
    
    sfa_class 'interface'
    
    #sfa :hardware_type, String, :attr_value => :name, :has_many => true
    #sfa :available, :attr_value => :name
    sfa :sliver_type, :attr_value => :name
    #sfa :public_ipv4, :ip4, :attribute => true
    sfa :role, :attribute => true

  end
  
end # OMF::SFA

if $0 == __FILE__
  OMF::Common::Loggable.init_log 'resource'

  OMF::SFA::Resource::Node.default_component_id = "urn+xxx"
  n = OMF::SFA::Resource::Node.new
  n.available = false
  n.add_hardware_type :foo
  
  doc =  n.to_sfa_xml()
  puts doc
end