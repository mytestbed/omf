
require 'omf-sfa/resource/resource'

module OMF::SFA::Resource
  
  class Component < Resource

    rspec :component_id, :is_attribute => true, :default_proc => :def_component_id # "urn:publicid:IDN+plc:cornell+node+planetlab3-dsl.cs.cornell.edu" 
    #property :component_manager_id, :is_attribute => true, :default_proc => :component_manager_id # "urn:publicid:IDN+plc+authority+am" 
    rspec :component_name, :is_attribute => true # "planetlab3-dsl.cs.cornell.edu" 
    rspec :exclusive, :type => :boolean, :is_attribute => true #="false">    

  end
  
end # OMF::SFA