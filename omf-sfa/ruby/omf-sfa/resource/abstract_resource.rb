require 'rubygems'
require 'dm-core'

require 'omf-sfa/resource/base'

module OMF::SFA::Resource
  
  class AbstractResource < OMF::Common::MObject
    include DataMapper::Resource
    #include Base
    #append_inclusions Base
    
    property :id,   Serial
    property :rtype, Discriminator
  #  property :name, String, :required => true
    
    def initialize(name = nil)
      #raise "ABSTRACT"
      super()
      _logger(name)
    end
    
  end
  
end # OMF::SFA