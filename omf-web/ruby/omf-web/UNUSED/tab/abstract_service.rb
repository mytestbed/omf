
#require 'json'
require 'omf-common/mobject'

module OMF::Web::Tab
  
  class AbstractService < MObject
    
    def initialize(tab_id, opts)
      @opts = opts
      @tab_id = tab_id
    end 
    

  end # AbstractService
  
  
end # OMF::Web::Tab