


require 'omf-sfa/resource/abstract_resource'
require 'omf-sfa/resource/gurn'

module OMF::SFA::Resource

#    <property capacity="100000" dest_id="urn:publicid:IDN+emulab.net+interface+internet:border" latency="0" packet_loss="0" source_id="urn:publicid:IDN+emulab.net+interface+pc233:eth0"/>    
      
   class LinkProperty < AbstractResource
     sfa_class 'property'
    
     sfa :capacity, Integer, :attribute => true
     sfa :latency, Integer, :attribute => true
     sfa :packet_loss, Integer, :attribute => true

     sfa :source_id, GURN, :attribute => true
     sfa :dest_id, GURN, :attribute => true
     
     @@opts2obj = {}
     
     def self.create(opts = {})
       # o = @@opts2obj[opts]
       # return o if o
       
       o = self.new
       opts.each do |k, v|
         o.sfa_property_set(k, v)
       end
       o
     end
   end
end # OMF::SFA::Resource
