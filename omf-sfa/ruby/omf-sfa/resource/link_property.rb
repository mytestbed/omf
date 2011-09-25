


require 'omf-sfa/resource/abstract_resource'
require 'omf-sfa/resource/gurn'

module OMF::SFA::Resource

#    <property capacity="100000" dest_id="urn:publicid:IDN+emulab.net+interface+internet:border" latency="0" packet_loss="0" source_id="urn:publicid:IDN+emulab.net+interface+pc233:eth0"/>    
      
   class LinkProperty < AbstractResource

     property :capacity, Integer
     property :latency, Integer
     property :packet_loss, Integer
     #sfa :source_id, GURN, :attribute => true
     #sfa :dest_id, GURN, :attribute => true

     sfa_class 'property'
     sfa :capacity, :attribute => true
     sfa :latency, :attribute => true
     sfa :packet_loss, :attribute => true

     sfa :source_id, :attribute => true
     sfa :dest_id, :attribute => true
     
     #@@opts2obj = {}  # not sure if shared link properties make sense
     
     def self.sfa_create(name_or_def = {}, context = nil)
       #puts "LINK_PROP: #{name_or_def.inspect}||||#{context}"       
       # o = @@opts2obj[opts]
       # return o if o
       
       if name_or_def.kind_of? Hash
         o = self.new
         name_or_def.each do |k, v|
           o.sfa_property_set(k, v)
         end
         return o
       else
         raise "Expected Hash as first argument, but got '#{name_or_def.inspect}' instead"
       end
     end
     
     def source_id
       "SOURCE_ID"
     end
     
     def dest_id
       "DEST_ID"
     end
     
   end
end # OMF::SFA::Resource
