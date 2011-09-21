
require 'nokogiri'   
require 'time' 
require 'omf-common/mobject2'
require 'omf-sfa/resource'
require 'omf-sfa/resource/gurn'



module OMF::SFA
  module Resource
  
    module Base
      
      def self.included(base)
        base.extend(ClassMethods)
      end
  
      module ClassMethods
        @@sfa_defs = {}
  
        def sfa_class(name = nil, opts = {})
          if name
            sfa_defs()['_class_'] = opts.merge(:name => name.to_s)
          else
            #puts ">>> #{sfa_def_for('_class_').inspect}"
            sfa_def_for('_class_')
          end
        end
        
        def sfa(name, type, opts = {})
          #puts ">>>> RSSPEC #{name}::#{self}::#{@@sfa_defs.inspect}"
          name = name.to_s
          opts[:type] = type
          props = sfa_defs()
          props[name] = opts
          if opts[:has_many]
            define_method name.to_sym do
              @values[name] ||= []
            end
            define_method "#{name}_add".to_sym do |val|
              # if (type == GURN)
                # val = GURN.create(val, self)
              # end
              # @values[name] = val
              (@values[name] ||= []) << val
            end
            
          else
            define_method "#{name}=".to_sym do |val|
              # if (type == GURN)
                # val = GURN.create(val, self)
              # end
              # @values[name] = val
              sfa_property_set(name, val)
            end
            define_method name.to_sym do 
              @values[name]
            end    
          end
          # This may break in 1.9, then use the cleaner 'define_singleton_method'
          (class << self; self; end).instance_eval do
            define_method "default_#{name}=".to_sym do |val|
              if (type == GURN)
                val = GURN.create(val)
              end
              sfa_def_for(name)[:default] = val
            end
          end  
        end
        
        # opts:
        #   :valid_for - valid [sec] from now
        #
        def sfa_advertisement_xml(resources, opts = {})
          doc = Nokogiri::XML::Document.new
          #<rspec expires="2011-09-13T09:07:09Z" generated="2011-09-13T09:07:09Z" type="advertisement" xmlns="http://www.protogeni.net/resources/rspec/2" xmlns:emulab="http://www.protogeni.net/resources/rspec/ext/emulab/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.protogeni.net/resources/rspec/2 http://www.protogeni.net/resources/rspec/2/ad.xsd http://www.protogeni.net/resources/rspec/ext/emulab/1 http://www.protogeni.net/resources/rspec/ext/emulab/1/ptop_extension.xsd http://company.com/rspec/ext/stitch/1 http://company.com/rspec/ext/stitch/1/ad.xsd ">  
          root = doc.add_child(Nokogiri::XML::Element.new('rspec', doc))
          root.set_attribute('type', "advertisement")
          now = Time.now
          root.set_attribute('generated', now.iso8601)
          root.set_attribute('expires', (now + (opts[:valid_for] || 600)).iso8601)
          _to_sfa_xml(resources, root, opts)          
        end
        
        def _to_sfa_xml(resources, root, opts = {})
          root.add_namespace(nil, "http://www.protogeni.net/resources/rspec/2")
          root.add_namespace('omf', 'http://schema.mytestbed.net/sfa/rspec/1')
          #root = doc.create_element('rspec', doc)
          #doc.add_child root
          obj2id = {}
          resources.each do |r|
            r._to_sfa_xml(root, obj2id, opts)
          end
          root.document   
        end
        
        def sfa_defs()
          unless props = @@sfa_defs[self]
            # this assumes that all the properties of the super classes are already set
            props = {}
            klass = self
            while klass = klass.superclass
              if sp = @@sfa_defs[klass]
                props = sp.merge(props)
              end
            end
            #puts "PROP #{self}:#{props.keys.inspect}"
            @@sfa_defs[self] = props
          end
          props
        end

        def sfa_def_for(name)
          sfa_defs()[name.to_s]
        end
        
      end
      
      def initialize(*args)
        super *args
        @values = {}
      end
      
      def sfa_id=(id)
        @values['_id'] = id
      end
      
      def sfa_id()
        @values['_id'] ||= "c#{object_id}"
      end
      
      def sfa_class()
        self.class.sfa_class()[:name]
      end
      
      def sfa_property_set(name, value)
        pdef = self.class.sfa_def_for(name)
        raise "Unknow SFA property '#{name}'" unless pdef
        type = pdef[:type]
        if type.kind_of?(Symbol)
          if type == :boolean
            unless value.kind_of?(TrueClass) || value.kind_of?(FalseClass)
              raise "Wrong type for '#{name}', is #{value.type}, but should be #{type}"
            end
          else 
            raise "Unknown type '#{type}', use real Class"
          end
        elsif !(value.kind_of?(type))
          if type.respond_to? :create
            value = type.create(value)
          else
            raise "Wrong type for '#{name}', is #{value.class}, but should be #{type}"
          end
#          puts "XXX>>> #{name}--#{! value.kind_of?(type)}--#{value.class}||#{type}||#{pdef.inspect}"
          
        end
        @values[name.to_s] = value
      end
      
      def sfa_property(name)
        @values[name.to_s]
      end

      def _xml_name()
        if pd = self.class.sfa_class
          return pd[:name]
        end
        self.class.name.gsub('::', '_')
      end
              
      def _to_sfa_xml(parent, obj2id, opts)
        n = parent.add_child(Nokogiri::XML::Element.new(_xml_name(), parent.document))
        defs = self.class.sfa_defs()
        if (id = obj2id[self])
          n.set_attribute('idref', id)
          return
        end
        
        id = sfa_id()
        obj2id[self] = id
        n.set_attribute('id', id)
        
        #puts "VALUES: #{@values.keys.inspect}"
        defs.keys.sort.each do |k|
          next if k.start_with?('_')
          pdef = defs[k]
          v = @values[k]
          #puts "#{k} <#{v}> #{pdef.inspect}"
          if v.nil?
            v = pdef[:default]
          end
          unless v.nil?
            _to_sfa_property_xml(k, v, n, pdef, obj2id, opts)
          end
        end
        parent
      end
      
      def _to_sfa_property_xml(pname, value, res_el, pdef, obj2id, opts)
        if pdef[:attribute]
          res_el.set_attribute(pname, value.to_s)
        elsif aname = pdef[:attr_value]
          el = res_el.add_child(Nokogiri::XML::Element.new(pname, res_el.document))
          el.set_attribute(aname, value.to_s)
        else
          if pdef[:inline] == true
            cel = res_el
          else
            cel = res_el.add_child(Nokogiri::XML::Element.new(pname, res_el.document))
          end
          if value.kind_of? Enumerable
            value.each do |o|
              if o.kind_of? OMF::SFA::Resource::Base
                o._to_sfa_xml(cel, obj2id, opts)
              else 
                el = cel.add_child(Nokogiri::XML::Element.new(pname, cel.document))
                #puts (el.methods - Object.new.methods).sort.inspect
                el.content = o.to_s
                #el.set_attribute('type', (pdef[:type] || 'string').to_s)
              end
            end
          else
            cel.content = value.to_s
            #cel.set_attribute('type', (pdef[:type] || 'string').to_s)
          end
        end
      end
        
      
    end # class Resource
  end # module Resource
end # OMF::SFA