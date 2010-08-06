require 'web/renderer'
require 'web/helpers'
include OMF::Admin::Web

module OMF
  module Admin
    module Web
      module Testbeds
        VIEW = :testbeds
        
        def self.configure(server, options = {})
          opts = options.dup
          server.mount('/testbeds/show', TestbedsServlet, opts)
          server.addTab(VIEW, "/testbeds/show", :name => 'Testbeds', 
              :title => "Add, edit and remove testbeds")
          server.mount('/testbeds/edit', EditTestbedsServlet, opts)
        end

        class TestbedsServlet < WEBrick::HTTPServlet::AbstractServlet
          
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
            res.body = MabRenderer.render('show', opts)
          end
          
        end
        
        class EditTestbedsServlet < WEBrick::HTTPServlet::AbstractServlet
          
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
            res.body = MabRenderer.render('edit', opts)
          end
          
        end
        
      end
    end
  end
end
