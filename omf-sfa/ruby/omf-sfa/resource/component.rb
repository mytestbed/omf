
require 'omf-sfa/resource/abstract_resource'

module OMF::SFA::Resource
  
  class Component < AbstractResource
    
    sfa :component_id, GURN, :attribute => true # "urn:publicid:IDN+plc:cornell+node+planetlab3-dsl.cs.cornell.edu" 
    sfa :component_manager_id, GURN, :attribute => true # "urn:publicid:IDN+plc+authority+am" 
    sfa :component_name, String, :attribute => true # "planetlab3-dsl.cs.cornell.edu" 
    sfa :exclusive, :boolean, :is_attribute => true #="false"> 
       
    def initialize(component_name, component_id = nil)
      super(component_name)
      self.component_name = component_name
      self.component_id = component_id || component_name
    end
  end
  
end # OMF::SFA