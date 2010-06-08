require 'json'

module OMF
  module ExperimentController
    module Web
      module Graph2
        @@graphs = []
        
        def self.configure(server, options = {})
          opts = options.dup
          opts[:graphs] = @@graphs
          server.mount('/graph2/show', GraphServlet, opts)
          server.mount('/graph2/update', UpdateServlet, opts)
          
#          if NodeHandler.debug?
#            debug_init()
#          end
          
          server.addTab :graph2, "/graph2/show", :name => "Graphs", :title => "All defined graphs"
        end
        
        def self.addGraph(name, opts = {}, &dataProc)
          g = {}
          g[:name] = name
          g[:gopts] = opts
          g[:dataProc] = dataProc
          @@graphs << g
        end

        class GraphDescription
          @@sessions = {}

          attr_reader :lines, :sessionID
          
          def addLine(data, lopts = {})
            l = lopts.dup
            l[:data] = data
            @lines << l
          end      
          
          def session()
            unless session = @@sessions[@sessionID]
              session = @@sessions[@sessionID] = {}
            end
            session
          end    
          
          def opts()
            @opts[:gopts]
          end
          
          def initialize(sessionID, opts)
            @sessionID = sessionID
            @opts = opts
            @lines = []
            if (dataProc = opts[:dataProc])
              dataProc.call(self)
#              g[:ldata] = graph.lines.to_json 
            end
          end
        end
        
        class GraphServlet  < WEBrick::HTTPServlet::AbstractServlet
          
          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = :graph

            sessionID = opts[:session_id] = "sess#{(rand * 10000000).to_i}"
            gid = (req.query['id'] || 0).to_i
            opts[:show_graph_id] = gid
  
            if gx = opts[:graphs][gid]
              opts[:gd] = GraphDescription.new(sessionID, gx)
            else
              opts[:gd] = nil
              opts[:flash][:alert] = "Unknown graph id '#{gid}'"
            end
            res.body = MabRenderer.render('graph2/show', opts, ViewHelper)
          end
        end

      
        class UpdateServlet  < WEBrick::HTTPServlet::AbstractServlet
  
          def do_GET(req, res)
            res['Content-Type'] = "text/json"
            opts = @options[0]
            gid = (req.query['id'] || 0).to_i
            
            res['Content-Type'] = "application/ecmascript"
            if gx = opts[:graphs][gid]
              sessionID = req.query['sid'] || 'unknown'
              gd = GraphDescription.new(sessionID, gx)
              res.body = "plot(#{gd.lines.to_json});"
            else
              res.body('');
            end
          end
        end
        
      end
    end
  end
end
