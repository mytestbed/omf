
require 'omf-sfa/model/abstract_prop_description'

# An +ModelDataPropertyDescription+ holds all the relevant information 
# for describing properties of entities.
#

module OMF::SFA
  module Model
    
    class ModelDataPropertyDescription < AbstractPropertyDescription
      
      # <owl:DatatypeProperty rdf:about="#numHop">
      #   <rdfs:domain rdf:resource="#NetworkTransportElement"/>
      #   <rdfs:range rdf:resource="&xsd;int"/>
      # </owl:DatatypeProperty>
      #
      def parse_el(node_name, res_name, el)
        case node_name
        when 'XXX'
        else
          super
        end
      end
    
    end # ModelClassDescription
  end # Model
end # OMF::SFA
