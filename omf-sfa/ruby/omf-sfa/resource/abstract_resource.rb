require 'rubygems'
require 'dm-core'

require 'omf-sfa/resource/base'

module OMF::SFA::Resource
  
  class AbstractResource #< OMF::Common::MObject
    include DataMapper::Resource
    
    property :name, String

    # managing dm objct
    property :id,   Serial
    property :rtype, Discriminator  # supporting class hierarchy

    alias :name_ name
    def name
      unless name = name_
        c = sfa_class
        if c
          name =  "#{c}#{self.class.count}"
        else
          name = "unknown#{AbstractResource.count}"
        end
        self.name = name
      end
      name      
    end
      
  end
  
end # OMF::SFA