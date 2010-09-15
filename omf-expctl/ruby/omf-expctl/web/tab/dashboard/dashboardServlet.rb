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
          server.mount('/dashboard/set', DashboardSetServlet, opts)
          
          #TODO: This should most likely done in the webServer with a 
          # redirect to the first service
          #
          server.mount('/', DashboardServlet, opts)
          server.addTab(VIEW, "/dashboard/show", :name => 'Dashboard', 
              :title => "Show and interact with experiment status")
        end

        class DashboardServlet < WEBrick::HTTPServlet::AbstractServlet

          def do_GET(req, res)
	    MObject.debug(:dashboard, "OPTIONS: #{@options.inspect}")
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = VIEW

            res.body = MabRenderer.render('show', opts)
          end
        end

        class DashboardSetServlet < WEBrick::HTTPServlet::AbstractServlet

          def do_POST(req, res)
            opts = @options[0].dup
            pname = req.query['pname']
            value = req.query['value']
            prop = ExperimentProperty[pname]
            prop.set(value.to_s) if prop
            res.body = prop ? prop.value : "Unknown Property"
          end
        end
      end
    end
  end
end
