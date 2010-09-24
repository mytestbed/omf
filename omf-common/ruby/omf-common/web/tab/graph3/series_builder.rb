module OMF
  module Common
    module Web
      module Graph3
        # Serial data sets consist of a series of ordered records. 
        #
        class SeriesBuilder
          attr_reader :session, :opts
          
          def session()
            @gDescr.session
          end
          
          # Add a series.
          # 
          # darray - Array of data points where a data point is an array itself
          # opts - ???
          #
          def addSeries(darray, opts = {})
            l = opts.dup
            l[:values] = darray
            @series << l
          end      
          
        
          def self.build(buildProc, gDescr)
            b = self.new(gDescr)
            buildProc.call(b)
          end
          
          def initialize(gDescr)
            @series = []
            @gDescr = gDescr
          end
          
          def to_js()
            @series.to_json
          end
          
        end # SeriesBuilder
      end
    end
  end
end
