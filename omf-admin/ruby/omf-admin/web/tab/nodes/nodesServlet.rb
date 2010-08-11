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
          server.mount('/nodes', NodesServlet, opts)
          server.mount('/', NodesServlet, opts)
          server.addTab(VIEW, "/nodes", :name => 'Nodes', 
              :title => "Add, edit and remove testbed nodes")

        end

        class NodesServlet < WEBrick::HTTPServlet::AbstractServlet
          
          def do_GET(req, res)
            opts = @options[0].dup
            opts[:view] = VIEW
            
            @@currentTB = req.query['testbed'] if req.query['testbed']
              
            if req.query.has_key?('action')
              if req.query['action'] == 'edit'
                opts[:nd] = @@nodes.get(req.query['name'],@@currentTB).merge(req.query)
                res.body = MabRenderer.render('edit', opts)
              elsif req.query['action'] == 'remove'
                @@nodes.delete(req.query['name'],@@currentTB)
                opts[:flash][:notice] = "Node removed"
                res.body = MabRenderer.render('nodes', opts)
              end
            else
              res.body = MabRenderer.render('nodes', opts)
            end
            opts[:flash].clear            
          end
          
          def do_POST(req, res)
            newnode = Hash.new
            req.query.collect { | key, value |
              newnode["#{key}"] = value.to_s
            }
            result = @@nodes.edit(newnode)
            if  result == "OK"
              @options[0][:flash][:notice] = "Changes saved"
            else
              @options[0][:flash][:alert] = result
            end
            do_GET(req, res)
          end

        end
      end
    end
  end
end
