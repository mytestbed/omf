require 'omf-web/page'

module OMF::Web::Tab::Log
  
  class LogPage < Page
  
    def initialize(opts)
      super opts
      @card_title ||= 'Log'
    end
    
    def render_card_body
      
      table :id => :logList do

      end
      
      script :language => "JavaScript", :type => "text/javascript" do
        text %{
          L.provide(null, [['jquery.js', 'jquery.periodicalupdater.js']], function() {
            $.PeriodicalUpdater('#{@update_path}', {
                method: 'get',
                minTimeout: 2000,
                maxTimeout: 2 * 2000,
                type: 'json',
                maxCalls: 0,
                autoStop: 0 
            }, function(reply) {
                var data = 2;
            });
          });
        }          
      end      
    end
  end # LogPage
end # module
