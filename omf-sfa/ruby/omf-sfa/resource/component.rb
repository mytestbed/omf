
require 'omf-sfa/resource/abstract_resource'

module OMF::SFA::Resource
  
  class Component < AbstractResource
    
    property :domain, String #, readonly => true
    property :exclusive, Boolean

    sfa_add_namespace :omf, 'http://schema.mytestbed.net/sfa/rspec/1'
    
    sfa :component_id, :attribute => true # "urn:publicid:IDN+plc:cornell+node+planetlab3-dsl.cs.cornell.edu" 
    sfa :component_manager_id, :attribute => true # "urn:publicid:IDN+plc+authority+am" 
    sfa :component_name, :attribute => true # "plane
    sfa :exclusive, :is_attribute => true #="false"> 

    def self.default_domain=(dname)
      @@default_domain = dname
    end   

    def self.default_component_manager_id=(gurn)
      @@default_component_manager_id = GURN.create(gurn) 
    end   

    before :save do
      if self.name.nil?
        self.name = "c#{Component.count}"
      end
      if self.domain.nil?
        self.domain = @@default_domain
      end
    end
    
    def component_id
      @component_id ||= GURN.create(self.component_name, self)
    end
    
    def component_manager_id
      @component_manager_id ||= (@@default_component_manager_id ||= GURN.create("authority+am"))
    end

    def component_name
      self.name
    end

  end
  
end # OMF::SFA