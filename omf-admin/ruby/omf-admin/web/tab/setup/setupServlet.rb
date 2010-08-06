require 'web/renderer'
require 'web/helpers'
include OMF::Admin::Web

module OMF
  module Admin
    module Web
      module Setup
        VIEW = :setup
        
        def self.configure(server, options = {})
          opts = options.dup
          server.mount('/setup', SetupServlet, opts)
          server.addTab(VIEW, "/setup", :name => 'Setup',
              :title => "Configure general options")          
        end
        
        class SetupServlet < WEBrick::HTTPServlet::AbstractServlet

          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = VIEW
            opts[:show_file] = nil
            if i = req.query['id'] || 0
              opts[:show_file_id] = i.to_i
            else
              opts[:flash][:alert] = "Missing 'id'"
            end
            
            opts[:config] = @@config.get
            
            res.body = MabRenderer.render('setup', opts)
          end
          
          def do_POST(req, res)
            req.query.collect { | key, value | puts("#{key}: #{value}") }
            do_GET(req, res)
          end
        end
      end
    end
  end
end

