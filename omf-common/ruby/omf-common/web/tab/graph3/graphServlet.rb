require 'json'

module OMF
  module Common
    module Web
      module Graph3
        @@graphs = []
        
        def self.configure(server, options = {})
          opts = options.dup
          opts[:graphs] = @@graphs
          server.mount('/graph3/show', GraphServlet, opts)
          server.mount('/graph3/update', UpdateServlet, opts)
          
#          if NodeHandler.debug?
#            debug_init()
#          end
          
          server.addTab :graph3, "/graph3/show", :name => "PV Graphs", :title => "All defined graphs"
          
          if NodeHandler.debug?
            self.addGraph 'test'
          end
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
          
          def protovis()
            type = @opts[:gtype] || 'matrix'
            
            fname = File.join(File.dirname(__FILE__), "#{type}.js")
            unless File.exists?(fname)
              raise "Unknown graph type '#{type}"
            end
            File.read(fname)
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
              if opts[:graphs].length > 0
                opts[:flash][:alert] = "Unknown graph id '#{gid}'"
              else
                opts[:flash][:alert] = "No graphs defined"
              end
            
            end
            res.body = MabRenderer.render('graph3/show', opts) do "foo" end
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
              res.body = %{
var oml_data = {
  nodes: [
    {nodeName: 'node28'},
    {nodeName: 'node29'},
    {nodeName: 'node30'},
    {nodeName: 'node31'}
  ],
  links:[
    {source:0, target:1, value:1},  
    {source:0, target:2, value:2},  
    {source:0, target:3, value:3},  
    {source:1, target:1, value:4},  
    {source:1, target:2, value:5},  
    {source:1, target:3, value:6},  
    {source:0, target:0, value:7}
  ]
};
              }
            else
              res.body('');
            end
          end
        end
        
      end
    end
  end
end
