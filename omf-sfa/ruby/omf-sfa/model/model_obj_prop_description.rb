
require 'omf-sfa/model/abstract_prop_description'

# An +ModelObjectPropertyDescription+ holds all the relevant information 
# for describing relationship between entities.
#

module OMF::SFA
  module Model
    
    class ModelObjectPropertyDescription < AbstractPropertyDescription
      
      @@types = {
        'http://www.w3.org/2002/07/owl#TransitiveProperty' => :transitive,
        'http://www.w3.org/2002/07/owl#FunctionalProperty' => :functional,
        'http://www.w3.org/2002/07/owl#InverseFunctionalProperty' => :inverse_functional,
        'http://www.w3.org/2002/07/owl#SymmetricProperty' => :symmetric,
        'http://www.w3.org/2002/07/owl#AsymmetricProperty' => :asymmetric,
        'http://www.w3.org/2002/07/owl#ReflexiveProperty' => :reflexive,        
        'http://www.w3.org/2002/07/owl#IrreflexiveProperty' => :irreflexive
      }
      
      
      # <!-- http://geni-orca.renci.org/owl/topology.owl#connectedTo -->
      # 
      # <owl:ObjectProperty rdf:about="#connectedTo">
      #   <rdf:type rdf:resource="&owl;TransitiveProperty"/>
      #   <rdfs:range rdf:resource="#NetworkElement"/>
      #   <rdfs:domain rdf:resource="#NetworkElement"/>
      #   <rdfs:subPropertyOf rdf:resource="&layer;feature"/>
      # </owl:ObjectProperty>
      #
      def parse_el(node_name, res_name, el)
        case node_name
        when 'subPropertyOf'
          @subPropertyOf = res_name
        when 'type'
          @type = @@types[res_name] || raise("Unknonw property type '#{res_name}'")
        when 'inverseOf'
          @inverseOf = res_name
        else
          super
        end
      end
    

    end # ModelClassDescription
  end # Model
end # OMF::SFA
