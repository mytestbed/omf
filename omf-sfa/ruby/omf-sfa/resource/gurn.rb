
require 'omf-common/mobject2'
require 'omf-sfa/resource'

module OMF::SFA::Resource
#   
  class GURN #< OMF::Common::MObject
  
  
    @@def_prefix = 'urn:publicid:IDN+mytestbed.net'
    @@name2obj = {}
    
    def self.create(name, model = nil)
      return name if name.kind_of? self
      #puts "GUID: #{name}###{context}"

      obj = @@name2obj[name]
      return obj if obj
      
      # sfa_default_prefix()
      unless name.start_with?('urn')
        if model && model.respond_to?(:sfa_class)
          type =  model.sfa_class
          name = "#{@@def_prefix}+#{type}+#{name}"
        else
          name = "#{@@def_prefix}+#{name}"
        end
      end
      return @@name2obj[name] = self.new(name)
    end
    
    def self.sfa_create(name, context = nil)
      #puts "GUID: #{name}###{context}"

      obj = @@name2obj[name]
      return obj if obj
      
      # sfa_default_prefix()
      unless name.start_with?('urn')
        if context.class.respond_to?(:sfa_class)
          type =  context.class.sfa_class
          name = "#{@@def_prefix}+#{type}+#{name}"
        else
          name = "#{@@def_prefix}+#{name}"
        end
      end
      return @@name2obj[name] = self.new(name)
    end

    def self.default_prefix=(prefix)
      @@def_prefix = prefix
    end
    
    def self.default_prefix()
      @@def_prefix
    end
    
    def initialize(name)
      @name = name
    end
    
    def to_s
      @name
    end
    
  end # GURN
end # OMF::SFA    
    
module DataMapper
  class Property
    class GURN < String
      
      # Maximum length chosen based on recommendation:
      length 256

      def custom?
        true
      end

      def primitive?(value)
        value.kind_of?(OMF::SFA::Resource::GURN)
      end

      def valid?(value, negated = false)
        super || primitive?(value) #|| value.kind_of?(::String)
      end

      # We don't want this to be called, but the Model::Property calls
      # this one first before calling #set! on this instance again with
      # the value returned here. Hopefully this is the only place this 
      # happens. Therefore, we just return +value+ unchanged and take care
      # of casting in +load2+
      #
      def load(value)
        if value 
          if value.start_with?('urn')
            return OMF::SFA::Resource::GURN.create(value)
          end
          raise "BUG: Shouldn't be called anymore (#{value})"
        end
        nil
      end
      
      def load2(value, context_class)
        if value
          #puts "LOAD #{value}||#{value.class}||#{context.inspect}" 
          return OMF::SFA::Resource::GURN.create(value, context_class)
        end
        nil
      end

      def dump(value)
        value.to_s unless value.nil?
      end
      
      # Typecasts an arbitrary value to a GURN
      #
      # @param [Hash, #to_mash, #to_s] value
      #   value to be typecast
      #
      # @return [GURN]
      #   GURN constructed from value
      #
      # @api private
      def typecast_to_primitive(value)
        raise "BUG: Shouldn't be called anymore"
      end
      
      # @override
      def set(resource, value)
        #puts ">>> SET: #{resource}"
        set!(resource, load2(value, resource.class))
      end

      
    
    end # class GURN 
  end # class Property
end #module DataMapper
  
    

