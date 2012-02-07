
# An +MClass+ holds all the releevant information relevant to the
# specific model class in an overal model or schema.
#

module OMF::SFA
  module Model
    
    class ModelClassDescription < OMF::Common::MObject
      
      @@name2inst = {}
      
      def self.[](uri)
        @@name2inst[uri]
      end
      
      def self.each(&block)
        if block
          @@name2inst.values.each &block
        else
          @@name2inst.values
        end
      end
      
      def self.models()
        @@name2inst.values
      end
      
      def self.create_from_xml(cel)
        about = cel.attribute_with_ns('about', RDF_NS)
        name = xml_full_name(about.value, cel)
        klass = @@name2inst[name] ||= self.new(name)
        klass.parse(cel)
        klass
      end
      
      
      attr_reader :name, :ns, :uri
      
      def initialize(full_name)
        @uri = full_name
        @ns, @name = full_name.split('#')
        super @name
        @properties = {}
        @children = []
      end
      
      def add_property(prop_description)
        name = prop_description.name
        if p = @properties[name]
          if p != prop_description
            error "Trying to add additional property with smae name '#{name}'"
          end
        else
          @properties[name] = prop_description
        end
      end
      
      
      def parse(cel)
        cel.children.each do |el|
          node_name = el.node_name
          next if node_name == 'comment'
          
          case el.node_name
          when 'subClassOf'
            parse_super(el)
          when 'disjointWith'
            # <owl:disjointWith rdf:resource="#Item"/>
          when 'label'
            @label = el.content
          else
            warn "Unknown eleement '#{el.node_name}' in '#{self.class.name}'"
          end
        end
      end
    
      # TODO: Parsing of 'Restriction'
      #
      #  <rdfs:subClassOf rdf:resource="#NetworkElement"/>
      #  <rdfs:subClassOf>
      #      <owl:Restriction>
      #          <owl:onProperty rdf:resource="#hasSwitchMatrix"/>
      #          <owl:someValuesFrom rdf:resource="#SwitchMatrix"/>
      #      </owl:Restriction>
      #  </rdfs:subClassOf>
      #
      def parse_super(el)
        res = el.attribute_with_ns('resource', RDF_NS)
        if res
          if @superklass
            warn "Don't really know how to handle multiple inheritence in '#{@name}'"
          end
          @superklass = xml_full_name(res.value, el)
        end
        
      end
      
      def superklass
        unless @superklass.kind_of? self.class
          if klass = self.class[@superklass]
            @superklass = klass
            klass.add_child_class(self)
          end
        end
        @superklass
      end
      
      def add_child_class(class_model)
        @children << class_model
      end
      
      def describe(level = 0, max_level = 99)
        if !@properties.empty? || level == 0
          prefix = "  " * level
          puts "#{prefix}-------------------------"
          puts "#{prefix}Class: #{name}"
          describe_properties(prefix)
        end
        @children.each do |ch|
          ch.describe level + 1, max_level
        end
      end

      def describe_properties(prefix)
        # if superklass.kind_of? self.class
          # superklass.describe_properties
        # end
        @properties.each do |n, p|
          mark = p.kind_of?(ModelDataPropertyDescription) ? '=' : '>'
          puts "#{prefix}  #{mark} #{n}"
        end
      end
      
      def validate()
        superklass
      end
      
      def to_s
        "#{@name} (#{self.class.name}) - super: #{superklass || 'none'}"
      end

    end # ModelClassDescription
  end # Model
end # OMF::SFA
