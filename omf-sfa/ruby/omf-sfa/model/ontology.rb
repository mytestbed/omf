
# This file is parsing OWL and RDF files and is generating data 
# modesl from it.
#
require 'nokogiri'   
require "omf-common/mobject2"


module OMF; module SFA; end end

require 'omf-sfa/model/model_class_description'
require 'omf-sfa/model/model_obj_prop_description'
require 'omf-sfa/model/model_data_prop_description'

module OMF::SFA
  module Model
    
    OWL_NS = "http://www.w3.org/2002/07/owl#"
    RDF_NS = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    
    #
    # Return a fully qualified name. Specifically, if +name+
    # starts with '#', the default namespace of +context_el+ is
    # going to prepended.
    #
    def xml_full_name(name, context_el)
      if name.start_with? '#'
        name = context_el.namespaces["xmlns"] + name
        name.gsub!('##', '#') # remove '##' if ns also ends in '#'
      end
      name
    end
    
    class Ontology < OMF::Common::MObject
      
      # URL prefix which we serve from local directory
      LOCAL_PREFIX = 'http://geni-orca.renci.org/owl/'
      LOCAL_DIR = "#{File.dirname(__FILE__)}/../../../owl/"
      
      @@uri2inst = {}
      
      def self.import(uri)
        unless onto = @@uri2inst[uri]
          info "Loading ontology '#{uri}'"
          if uri.kind_of?(String) && uri.start_with?(LOCAL_PREFIX)
            file_name = uri.gsub(LOCAL_PREFIX, LOCAL_DIR)
            begin
              onto = @@uri2inst[uri] = self.new(file_name, true)
            rescue Errno::ENOENT
              puts ">>>> Unknown ontology '#{uri}'"
            end
          else
            raise "don't know how to import '#{uri}'"
          end
        end
        onto
      end
      
      def initialize(uri, is_file = false)
        @uri = uri
        if is_file
          f = File.open(uri)
          @doc = Nokogiri::XML(f) do |config|
            config.strict.noent.noblanks
          end
          f.close
        else
          raise "don't know how to import '#{uri}'"          
        end
        
        parse()
      end
      
      def parse()
        def_ns = @doc.namespaces["xmlns"]
        
        @doc.root.children.each do |el|
          case el.node_name
          when 'Ontology'
            parse_onotology(el)
          when 'Class'
            ModelClassDescription.create_from_xml(el)
          when 'comment'
            # ignore
          when 'ObjectProperty'
            ModelObjectPropertyDescription.create_from_xml(el)
          when 'DatatypeProperty'
            ModelDataPropertyDescription.create_from_xml(el)
          when 'AnnotationProperty'
            # ignore
          else
            warn "Unknown element '#{el.node_name}' in '#{@uri}'"
          end
        end


        # @doc.xpath('//owl:Class', 'owl' => OWL_NS).each do |cel|
          # debug ModelClassDescription.create_from_xml(cel)
          # #debug c.attribute_with_ns('about', RDF_NS)
          # #debug c.namespaces["xmlns"].inspect #def_ns
          # #debug c.inspect
          # #exit
        # end
      end
      
      private
      
      # <owl:Ontology rdf:about="">
          # <rdfs:label rdf:datatype="&xsd;string"
              # >Collections v. 1.2</rdfs:label>
          # <owl:versionInfo rdf:datatype="&xsd;string">1.2</owl:versionInfo>
          # <dc:date rdf:datatype="&xsd;string"
              # >January 14, 2009</dc:date>
          # <dc:contributor rdf:datatype="&xsd;string">Marco Ocana</dc:contributor>
          # <dc:contributor rdf:datatype="&xsd;string">Paolo Ciccarese</dc:contributor>
          # <dc:format rdf:datatype="&xsd;string">rdf/xml</dc:format>
          # <dc:language>en</dc:language>
          # <dc:title xml:lang="en"
              # >Collections ontology</dc:title>
      # </owl:Ontology>
      #
      
      def parse_onotology(el)
        el.children.each do |el|
          case el.node_name
          when 'imports'
            res = el.attribute_with_ns('resource', RDF_NS)
            self.class.import(res.value)
          else
            #warn "Unknown eleement '#{el.node_name}' in 'owl:Ontology'"
          end
        end
        
      end
    end
  end # Model
end # OMF::SFA

if $0 == __FILE__
  OMF::Common::Loggable.init_log 'owl'
  include OMF::SFA::Model
  
  #f = "#{File.dirname(__FILE__)}/../../../owl/topology.owl"
  
  ['topology', 'domain', 'storage', 'compute'].each do |o|
    u = "http://geni-orca.renci.org/owl/#{o}.owl"
    Ontology.import(u)
  end
  
  AbstractPropertyDescription.each do |p|
    p.validate
  end
  
  ModelClassDescription.each do |c|
    c.validate
  end
  
  roots = ModelClassDescription.models.select do |c|
    c.superklass.nil?
  end
  
  roots.each do |c|
    c.describe
  end
  

end

  