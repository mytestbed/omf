require 'json'
require 'omf-common/web/tab/graph3/graph_description'

module OMF
  module Common
    module Web
      module Graph3
        @@graphs = []
        @@sessions = {}
        
        def self.configure(server, options = {})
          opts = options.dup
          opts[:graphs] = @@graphs
          server.mount('/graph3/show', GraphServlet, opts)
          server.mount('/graph3/update', UpdateServlet, opts)
          server.addTab(:graph3, "/graph3/show", 
            :name => "PV Graphs", :title => "All defined graphs", :class => self)
        end
        
        def self.addGraph(name, visType, opts = {}, &dataProc)
          g = {}
          g[:name] = name
          g[:gopts] = opts
          g[:visType] = visType
          g[:dataProc] = dataProc
          @@graphs << g
        end

        def self.addNetworkGraph(name, opts = {}, &netProc)
          g = {}
          g[:name] = name
          g[:gopts] = opts.dup
          g[:netProc] = netProc
          @@graphs << g
        end



        
        class GraphServlet  < WEBrick::HTTPServlet::AbstractServlet
          
          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = :graph3

            sessionID = opts[:session_id] = "sess#{(rand * 10000000).to_i}"
            
            gid = (req.query['id'] || 0).to_i
            format = req.query['format'] || 'graph'
            opts[:show_graph_id] = gid
            if gx = opts[:graphs][gid]
              if (loadProc = opts[:fileLoadFunc])
                gx[:fileLoadFunc] = loadProc
              end
#              session = @@sessions[sessionID] ||= {}
#              session[:ts] = Time.now
              opts[:gd] = GraphDescription.new(sessionID, gx)
            else
              opts[:gd] = nil
              if opts[:graphs].length > 0
                opts[:flash][:alert] = "Unknown graph id '#{gid}'"
              else
                opts[:flash][:alert] = "No graphs defined"
              end
            
            end
            res.body = MabRenderer.render('graph3/show_' + format, opts)
          end
        end

      
        class UpdateServlet  < WEBrick::HTTPServlet::AbstractServlet
  
          def do_GET(req, res)
            res['Content-Type'] = "text/json"
            opts = @options[0]
            gid = (req.query['id'] || 0).to_i
            
            #res['Content-Type'] = "application/ecmascript"
            if gx = opts[:graphs][gid]
              unless (sessionID = req.query['sid'])
                raise "Missing session"
              end
#              session = @@sessions[sessionID] ||= {}
#              session[:ts] = Time.now
              gd = GraphDescription.new(sessionID, gx)
              body = {:data => gd.data, :opts => gx[:gopts]}
              res.body = body.to_json
	          else
              raise "Unknown graph" 
            end
          end
        end
        
      end
    end
  end
end
