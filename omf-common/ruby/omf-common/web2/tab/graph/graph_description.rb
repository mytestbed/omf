
module OMF::Common::Web2::Graph

  class GraphDescription < MObject
    
    attr_reader :name, :vizType, :vizOpts, :opts
    
    def initialize(name, vizType, opts)
      @name = name
      @vizType = vizType
      @opts = opts
      @vizOpts = @opts[:gopts] || {}
    end
        
    private

  end # GraphDescription
end
