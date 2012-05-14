
#require 'omf-common/mobject'

module OMF
  module Web
    module Tab; end
    module Rack; end
    module Widget; end
    
    def self.start(opts)
      require 'omf-web/runner'
      require 'thin'
      
      Thin::Logging.debug = true
      OMF::Web::Runner.new(ARGV, opts).run!      
    end
  end
end


