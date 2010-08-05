require 'web/renderer'
require 'web/helpers'
include OMF::Admin::Web

#
# A servlet to autodetect nodes
#
module OMF
  module Admin
    module Web
      module Nodes
        VIEW = :nodes
        
        
        def self.configure(server, options = {})
          opts = options.dup
          server.mount('/nodes/show', NodesServlet, opts)
          server.addTab(VIEW, "/nodes/show", :name => 'Nodes', 
              :title => "Add, edit and remove testbed nodes")

        end

        class NodesServlet < WEBrick::HTTPServlet::AbstractServlet
          
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
      end
    end
  end
end
