
require 'omf-common/mobject2'
require 'omf-sfa/resource'

module OMF::SFA::Resource
  
  class GURN < OMF::Common::MObject
  
    @@def_prefix = 'urn:publicid:IDN+mytestbed.net'
    @@name2obj = {}
    
    def self.sfa_create(name, context)
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
    
  end
  
end # OMF::SFA