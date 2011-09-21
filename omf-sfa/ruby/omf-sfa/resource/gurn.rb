
require 'omf-common/mobject2'
require 'omf-sfa/resource'

module OMF::SFA::Resource
  
  class GURN < OMF::Common::MObject
  
    @@def_prefix = 'urn:publicid:IDN+mytestbed.net'
    @@name2obj = {}
    
    def self.create(name, context = nil)
      puts "GUID: #{name}###{context}"
      obj = @@name2obj[name]
      return obj if obj
      
      # sfa_default_prefix()
      unless name.start_with?('urn')
        if context.respond_to?(:sfa_class)
          type =  context.sfa_class
          name = "#{@@def_prefix}+#{type}+#{name}"
        elsif context
          name = "#{@@def_prefix}+#{context}+#{name}"
        else
          name = "#{@@def_prefix}+#{name}"
        end
      end
      return self.new(name)
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