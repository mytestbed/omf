
require 'omf-sfa/resource/component'
require 'omf-sfa/resource/interface'
require 'omf-sfa/resource/link_property'

module OMF::SFA::Resource

  class Network < Component
    
    has n, :interfaces

    sfa_class 'network', :namespace => :omf
    sfa :interfaces, :inline => true, :has_many => true
    
  end
  
end # OMF::SFA
