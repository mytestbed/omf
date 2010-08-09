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
            opts[:view] = VIEW
            
            opts[:config] = @@config.get
            
            res.body = MabRenderer.render('setup', opts)
          end
          
          def do_POST(req, res)
            newconfig = @@config.get
            req.query.collect { | key, value |
              k = key.split(':')
              newconfig[:"#{k[0]}"][:"#{k[1]}"][:"#{k[2]}"] = value.to_s
            }
            @@config.set(newconfig)
            @@config.save
            @options[0][:flash][:notice] = "Configuration saved"
            do_GET(req, res)
          end
        end
      end
    end
  end
end

