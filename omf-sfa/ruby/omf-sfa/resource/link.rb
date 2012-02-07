

require 'omf-sfa/resource/network'
require 'omf-sfa/resource/link_property'

module OMF::SFA::Resource
  
      # <link component_id="urn:publicid:IDN+emulab.net+link+link-pc102%3Aeth2-internet%3Aborder" component_name="link-pc102:eth2-internet:border">    
        # <component_manager name="urn:publicid:IDN+emulab.net+authority+cm"/>    
          # <interface_ref component_id="urn:publicid:IDN+emulab.net+interface+pc102:eth2"/>    
          # <interface_ref component_id="urn:publicid:IDN+emulab.net+interface+internet:border"/>    
        # <property capacity="100000" dest_id="urn:publicid:IDN+emulab.net+interface+internet:border" latency="0" packet_loss="0" source_id="urn:publicid:IDN+emulab.net+interface+pc102:eth2"/>    
        # <property capacity="100000" dest_id="urn:publicid:IDN+emulab.net+interface+pc102:eth2" latency="0" packet_loss="0" source_id="urn:publicid:IDN+emulab.net+interface+internet:border"/>    
          # <link_type name="ipv4"/>    
      # </link>  
  
  class Link < Network
    
    property :link_type, String
    #has 2, :interfaces
    
    sfa_class 'link'
    sfa :link_type, :content_attribute => :name
    #sfa :properties, LinkProperty, :inline => true, :has_many => true

    # Override xml serialization of 'interface' 
    def _to_sfa_property_xml(pname, value, res_el, pdef, obj2id, opts)
      if pname == 'interfaces'
        value.each do |iface|
          el = res_el.add_child(Nokogiri::XML::Element.new('interface_ref', res_el.document))
          el.set_attribute('component_id', iface.component_id.to_s)
        end
        return        
      end
      super
    end
  end
  
end # OMF::SFA

