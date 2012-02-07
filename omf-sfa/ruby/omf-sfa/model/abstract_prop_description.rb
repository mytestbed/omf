

# An +ModelDataPropertyDescription+ holds all the relevant information 
# for describing properties of entities.
#

module OMF::SFA
  module Model
    
    class AbstractPropertyDescription < OMF::Common::MObject
      
      @@name2inst = {}
      
      def self.create_from_xml(cel)
        about = cel.attribute_with_ns('about', RDF_NS)
        name = xml_full_name(about.value, cel)
        klass = @@name2inst[name] ||= self.new(name)
        klass.parse(cel)
        klass
      end
      
      def self.each(&block)
        @@name2inst.values.each &block
      end
      
      attr_reader :name, :ns, :uri
      
      def initialize(full_name)
        @uri = full_name
        @ns, @name = full_name.split('#')
        super @name
      end
      
      def validate()
        if @domain 
          @domain = validate_class_reference(@domain)
          @domain.add_property(self)
        else
          #warn "No domain reference for property '#{@name}'"
        end
      end
      
      # Return class description for +ref+
      #
      def validate_class_reference(ref)
        unless ref.kind_of? ModelClassDescription
          if ref
            ref = ModelClassDescription[ref] || raise("Unknonw class '#{ref}'")
          else
            raise 'Empty class reference'
          end
        end
        ref
      end
      
      
      def parse(cel)
        cel.children.each do |el|
          node_name = el.node_name
          next if node_name == 'comment'

          attr = el.attribute_with_ns('resource', RDF_NS)
          res_name = attr ? xml_full_name(attr.value, el) : nil
          
          parse_el(node_name, res_name, el)
        end
      end
    
      def parse_el(node_name, res_name, el)
        case node_name
        when 'range'
          @range = res_name # ModelClassDescription[res] || raise("Unknonw class '#{res}'")
        when 'domain'
          @domain = res_name
        else
          warn "Unknown eleement '#{node_name}' in '#{self.class.name}'"
        end
      end
              
      
      def to_s
        "#{@name} (#{self.class.name})"
      end

    end # AbstractPropDescription
  end # Model
end # OMF::SFA
