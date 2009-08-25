#
# A servlet to display general experiment properties and allows for interacting
# with the experiment
#
module OMF
  module ExperimentController
    module Web
      module Dashboard
        VIEW = :dashboard
        
        def self.configure(server, options = {})
          opts = options.dup
          server.mount('/dashboard/show', DashboardServlet, opts)
          
          #TODO: This should most likely done in the webServer with a 
          # redirect to the first service
          #
          server.mount('/', DashboardServlet, opts)
          
          server.addTab(VIEW, "/dashboard/show", :name => 'Dashboard', 
              :title => "Show and interact with experiment status")
        end

        class DashboardServlet < WEBrick::HTTPServlet::AbstractServlet

          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = VIEW

            res.body = MabRenderer.render('dashboard/show', opts, ViewHelper)
          end
        end
      end
    end
  end
end
