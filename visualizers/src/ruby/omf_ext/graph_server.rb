require 'webrick'
require 'webrick/httputils'
require 'util/mobject'

module OMF
  module ExperimentController
    module Graph
      class ConfigServlet  < WEBrick::HTTPServlet::AbstractServlet

        def do_GET(req, res)
          res['Content-Type'] = "text/json"

          expID = "outdoor_2009_03_27_18_33_57"
          q = "select seq_no, oml_ts_client from otr2_udp_in;"
          #url = "http://console.outdoor.orbit-lab.org:5012/result/queryDatabase?expID=#{expID}&query=#{q}&format=json"
          url = "http://localhost:2000/graph/result?expID=#{expID}&query=#{q}&format=json"
          format = "json"
          
          res.body = %{
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
    end
  end
end
