

module OMF
  module ExperimentController
    module Web
      module Graph
        @@graphs = []
        
        def self.configure(server, options = {})
          opts = options.dup
          opts[:graphs] = @@graphs
          server.mount('/graph/show', GraphServlet, opts)
          server.mount('/graph/config', ConfigServlet, opts)
          server.mount('/graph/result', TestDataServlet)
          
          if NodeHandler.debug?
            debug_init()
          end
          
          server.addTab :graph, "/graph/show", :name => "Graphs", :title => "All defined graphs"
        end
        
        class GraphServlet  < WEBrick::HTTPServlet::AbstractServlet
  
          def do_GET(req, res)
            opts = @options[0].dup
            opts[:flash].clear
            opts[:view] = :graph
            gid = (req.query['id'] || 0).to_i
            opts[:show_graph_id] = gid
  
            #MObject.debug :web_graph_servlet, "OPTS: #{opts.inspect}"
            #opts[:flash][:notice] = opts.inspect
            res.body = MabRenderer.render('graph/show', opts, ViewHelper)
          end
        end

      
        class ConfigServlet  < WEBrick::HTTPServlet::AbstractServlet
  
          def do_GET(req, res)
            res['Content-Type'] = "text/json"
            gid = (req.query['id'] || 0).to_i
            opts = @options[0]
            g = opts[:graphs][gid]
            if g
              res.body = g[:config]
            end
  
#            expID = OMF::ExperimentController::Web::ViewHelper.exp_id()
#            #expID = "outdoor_2009_03_27_18_33_57"
#            
#            q = "select seq_no, oml_ts_client from otr2_udp_in;"
#            url = "http://console.outdoor.orbit-lab.org:5012/result/queryDatabase?expID=#{expID}&query=#{q}&format=json"
#            #url = "http://localhost:2000/graph/result?expID=#{expID}&query=#{q}&format=json"
#            format = "json"
#            
#            res.body = %{
#        {"omf_vis": {
#          "type": "timeline",
#          "data" : {
#            "format": "#{format}",
#            "url": "#{URI.escape(url)}"
#          },
#          "config": { 
#            "axis": {
#              "x": {"field": "oml_ts_client", "flush": false},
#              "y": {"field" : "seq_no"}
#            },
#            "encoders": [
#              {"type": "color", 
#                "source": "cause", "group": "nodes", 
#                "target" : "fillColor", "scaleType" : "categories"},
#              {"type": "color", 
#                "source": "series", "group": "edges", 
#                "target" : "lineColor", "scaleType" : "categories"},
#              {"type": "property", 
#                "lineAlpha": 0, "alpha": 0.5, "buttonMode": false,
#                "scaleX": 1, "scaleY": 1, "size": 0.5},
#              {"type": "property", "group": "edges",
#                "lineWidth": 1}
#            ]
#          }
#        }}
#        }
          end
        end
        
        class TestDataServlet  < WEBrick::HTTPServlet::AbstractServlet
  
          def do_GET(req, res)
            res['Content-Type'] = "text/json"
            res.body = %{
  {"oml_res" : {
    "columns" : ["seq_no", "oml_ts_client"],
    "rows" : [[2,2], [3,3], [4,4], [5,6]]
  }}
            }
          end
          
        end
        
        def self.debug_init
          g = {}
          g[:name] = 'pkts_received'
          g[:query] = "select seq_no, oml_ts_client from otr2_udp_in;"
          
          expID = OMF::ExperimentController::Web::ViewHelper.exp_id()
          q = "select seq_no, oml_ts_client from otr2_udp_in;"
          url = "http://console.outdoor.orbit-lab.org:5012/result/queryDatabase?expID=#{expID}&query=#{q}&format=json"
          format = "json"
          g[:query_url] = url
          g[:config] = %{
{"omf_vis": {
  "type": "timeline",
  "data" : {
    "format": "#{format}",
    "url": "#{URI.escape(url)}"
  },
  "config": { 
    "axis": {
      "x": {"field": "oml_ts_client", "flush": false},
      "y": {"field" : "seq_no"}
    },
    "encoders": [
      {"type": "color", 
        "source": "cause", "group": "nodes", 
        "target" : "fillColor", "scaleType" : "categories"},
      {"type": "color", 
        "source": "series", "group": "edges", 
        "target" : "lineColor", "scaleType" : "categories"},
      {"type": "property", 
        "lineAlpha": 0, "alpha": 0.5, "buttonMode": false,
        "scaleX": 1, "scaleY": 1, "size": 0.5},
      {"type": "property", "group": "edges",
        "lineWidth": 1}
    ]
  }
}}
          }
          @@graphs << g
        end
      end
    end
  end
end
