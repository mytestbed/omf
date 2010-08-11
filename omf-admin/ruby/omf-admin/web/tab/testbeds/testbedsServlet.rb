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
          server.mount('/testbeds', TestbedsServlet, opts)
          server.addTab(VIEW, "/testbeds", :name => 'Testbeds', 
              :title => "Add, edit and remove testbeds")
        end

        class TestbedsServlet < WEBrick::HTTPServlet::AbstractServlet
          
          def do_GET(req, res)
            opts = @options[0].dup
            opts[:view] = VIEW
            
            if req.query.has_key?('action')
              if req.query['action'] == 'edit'
                opts[:tb] = req.query
                res.body = MabRenderer.render('edit', opts)
              elsif req.query['action'] == 'remove'
                result = @@testbeds.delete(req.query['name'])
                if result == "OK"
                  opts[:flash][:notice] = "Testbed deleted"
                else
                  opts[:flash][:alert] = result
                end
                res.body = MabRenderer.render('testbeds', opts)
              end
            else
              res.body = MabRenderer.render('testbeds', opts)
            end
            opts[:flash].clear            
          end
          
          def do_POST(req, res)
            newtb = Hash.new
            req.query.collect { | key, value |
              newtb["#{key}"] = value.to_s
            }
            result = @@testbeds.edit(newtb)
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
