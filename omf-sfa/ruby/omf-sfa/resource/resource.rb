
require 'nokogiri'    
require 'omf-common/mobject2'

if $0 == __FILE__
  module OMF; module SFA; end end
end

module OMF::SFA
  module Resource
  
    class Resource < OMF::Common::MObject
      @@properties = {}
      
      def self.rspec_class(name)
        rspec('_class_', :name => name)
      end
      
      def self.rspec(name, opts = {})
        #puts "DEFINE #{name}::#{self}::#{@@properties[self]}"
        unless props = @@properties[self]
          # this assumes that all the properties of the super classes are already set
          props = {}
          klass = self
          while klass = klass.superclass
            if sp = @@properties[klass]
              props = sp.merge(props)
            end
          end
          #puts "PROP #{self}:#{props.keys.inspect}"
          @@properties[self] = props
        end
        props[name.to_s] = opts
        if opts[:is_functional] == false
          define_method "add_#{name}".to_sym do |val|
            (@values[name] ||= []) << val
          end
        else
          define_method "#{name}=".to_sym do |val|
            @values[name] = val
          end
        end
        define_method name.to_sym do 
          @values[name]
        end
        # This may break in 1.9, then use the cleaner 'define_singleton_method'
        (class << self; self; end).instance_eval do
          define_method "default_#{name}=".to_sym do |val|
            sfa_def_for(name)[:default] = val
          end
        end

      end
      
      def self.sfa_def_for(name)
        name = name.to_s
        klass = self
        while klass
          if p = @@properties[klass]
            pd = p[name]
            return pd if pd
          end
          klass = klass.superclass
        end
        nil
      end
      
      def initialize(loggerName = nil)
        super
        @values = {}
        _set_value '_name_', (@@properties[self.class] ||= {})['_name_']
      end
      
      # Return sfa declarations for this instance
      #
      def _sfa_defs()
        @@properties[self.class]
      end
      
      def _value(name)
        #(@@properties[self] ||= {})[name.to_sym]
        @values[name.to_s]
      end

      def _set_value(name, value)
        #(@@properties[self] ||= {})[name.to_sym] = value
        @values[name.to_s] = value
      end
      
      def _xml_name()
        if pd = _sfa_defs()['_class_']
          return pd[:name]
        end
        self.class.name.gsub('::', '_')
      end
              
      def to_xml(parent = nil)
        unless parent
          parent = Nokogiri::XML::Document.new
        end
        n = parent.add_child(Nokogiri::XML::Element.new(_xml_name, parent.document))
        defs = _sfa_defs()
        defs.keys.sort.each do |k|
          next if k.start_with?('_')
          pdef = defs[k]
          v = @values[k]
          if v.nil?
            #puts ">>> #{k}::#{pdef.inspect}"
            v = pdef[:default]
          end
          if v
            if pdef[:is_attribute]
              n.set_attribute(k, v.to_s)
            end
          end
        end
        parent
      end
      
    end # class Resource
  end # module Resource
end # OMF::SFA