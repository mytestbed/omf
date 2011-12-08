
require 'omf-common/web/helpers'

module OMF
  module EC
    module Web
      class ViewHelper < OMF::Common::Web::ViewHelper

        @@exp_id = nil
        
        def self.exp_id
          sliceID = Experiment.sliceID
          if sliceID
            "#{sliceID}: #{Experiment.ID}"              
          else
            "#{Experiment.ID}"
          end
        end
        
      end
    end
  end
end
