
require 'omf-sfa/resource/component'
require 'omf-sfa/resource/interface'

module OMF::SFA::Resource
  
  class Node < Component
    property :hardware_type, String
    property :available, Boolean
    property :sliver_type, String
    has n, :interfaces

    sfa_class 'node'
    sfa :hardware_type, :inline => true, :has_many => true
    sfa :available, :attr_value => 'now'  # <available now="true">
    sfa :sliver_type, :attr_value => 'name'
    sfa :interfaces, :inline => true, :has_many => true
    
  end
  
end # OMF::SFA

